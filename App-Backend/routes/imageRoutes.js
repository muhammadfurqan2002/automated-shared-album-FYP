const express = require("express");
const { authenticateJWT } = require("../middlewares/authMiddleware");
const {
  createImageController,
  getImagesController,
  deleteImageController,
  getDuplicateImagesController,
  getBlurImagesController,
  deleteMultipleImagesController,
  unflagBlurImageController,
  unflagDuplicateImageController,
  unflagMultipleBlurImagesController,
  unflagMultipleDuplicateImagesController,
} = require("../controllers/imageController");
const batchService = require("../services/batchService");
const s3Service = require("../services/s3Service");
const userModel = require("../models/userModel");
const router = express.Router();

router.post("/", authenticateJWT, createImageController);
router.get("/:albumId", authenticateJWT, getImagesController);
router.get(
  "/:albumId/duplicate",
  authenticateJWT,
  getDuplicateImagesController
);
router.get("/:albumId/blur", authenticateJWT, getBlurImagesController);
router.delete("/:imageId", authenticateJWT, deleteImageController);
router.post("/delete-flagged", authenticateJWT, deleteMultipleImagesController);
router.put("/:imageId/unflag-blur", authenticateJWT, unflagBlurImageController);
router.put(
  "/:imageId/unflag-duplicate",
  authenticateJWT,
  unflagDuplicateImageController
);
router.put("/unflag-blur", authenticateJWT, unflagMultipleBlurImagesController);
router.put(
  "/unflag-duplicate",
  authenticateJWT,
  unflagMultipleDuplicateImagesController
);

router.post("/images-presign", authenticateJWT, async (req, res) => {
  try {
    const { fileName, fileType, albumId } = req.body;
    const participant = await userModel.getUserAccessRole(albumId, req.user.id);

    if (!participant || participant !== "admin") {
      return res.status(403).json({
        error: `Only admins are allowed to upload.`,
      });
    }

    console.log(albumId, fileType, fileName, "details");
    const { uploadURL, s3ImageUrl, fileKey } =
      await s3Service.generateImageUploadUrl(
        fileName,
        fileType,
        albumId,
        req.user.id
      );
    const message = {
      s3: {
        bucket: { name: process.env.AWS_BUCKET_NAME },
        object: { key: fileKey },
      },
      metadata: {
        albumId: albumId,
        userId: req.user.id,
        fileName: fileName,
      },
    };
    await batchService.enqueueBatch([message]);

    return res.status(200).json({ uploadURL, s3ImageUrl });
  } catch (error) {
    console.error("Error generating presigned URL:", error);
    return res.status(500).json({ error: "Failed to generate presigned URL" });
  }
});
module.exports = router;
