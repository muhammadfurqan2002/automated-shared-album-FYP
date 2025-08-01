const imageService = require("../services/imageService");
const redisClient = require("../utils/redis");
const userModel=require('../models/userModel')
const {
  invalidateAlbumImageCaches,
  invalidateBlurCache,
  invalidateDuplicateCache,
  invalidateAlbumImagesCache,
  invalidateByPattern,
} = require("../utils/cache");

async function createImageController(req, res) {
  try {
    const { albumId, fileName, s3ImageUrl } = req.body;
    const image = await imageService.createImageService({
      albumId,
      userId: req.user.id,
      fileName,
      s3ImageUrl,
    });

    await invalidateAlbumImageCaches(redisClient, albumId);
    await invalidateByPattern(redisClient, `user_storage_usage:${req.user.id}`);
    await invalidateByPattern(redisClient, `suggestions_manual:${albumId}`);

    res.status(201).json(image);
  } catch (error) {
    console.error("Error in createImageController:", error);
    res.status(500).json({ error: "Failed to create image" });
  }
}

async function getImagesController(req, res) {
  try {
    const { albumId } = req.params;
    const userId=req.user.id;
    const duplicate = req.query.duplicate;
    const status = req.query.status;
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 10;
    const skip = (page - 1) * limit;

    
      const participant = await userModel.getUserAccessRole(albumId, userId);

      if (!participant) {
        return res.status(403).json({
          error: `You don't have access to that album.`,
        });
      }
    
    const cacheKey = `album_images:${albumId}:p${page}:l${limit}:d${
      duplicate || "n"
    }:s${status || "all"}`;

    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.status(200).json(JSON.parse(cached));
    }

    const images = await imageService.getImagesService(
      albumId,
      duplicate,
      status,
      skip,
      limit
    );
    const response = { page, limit, images };

    await redisClient.set(cacheKey, JSON.stringify(response), "EX", 180);

    console.log(response);
    res.status(200).json(response);
  } catch (error) {
    console.error("Error in getImagesController:", error);
    res.status(500).json({ error: "Failed to get images" });
  }
}

async function getBlurImagesController(req, res) {
  try {
    const userId=req.user.id;
    const { albumId } = req.params;
    const status = req.query.status;
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 10;
    const skip = (page - 1) * limit;

    
      const participant = await userModel.getUserAccessRole(albumId, userId);

      if (!participant || participant !== 'admin') {
        return res.status(403).json({
          error: `Only album admin can review.`,
        });
      }
    


    const cacheKey = `blur_images:${albumId}:p${page}:l${limit}:s${
      status || "all"
    }`;

    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.status(200).json(JSON.parse(cached));
    }
    const images = await imageService.getBlurImagesService(
      albumId,
      status,
      skip,
      limit
    );
    const response = { page, limit, images };
    await redisClient.set(cacheKey, JSON.stringify(response), "EX", 180);
    console.log("blur images");
    console.log(images);
    res.status(200).json(response);
  } catch (error) {
    console.error("Error in getImagesController:", error);
    res.status(500).json({ error: "Failed to get images" });
  }
}

async function getDuplicateImagesController(req, res) {
  try {
    const { albumId } = req.params;
    const userId=req.user.id;
    const duplicate = req.query.duplicate;
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 10;
    const skip = (page - 1) * limit;

    const participant = await userModel.getUserAccessRole(albumId, userId);

      if (!participant || participant !== 'admin') {
        return res.status(403).json({
          error: `Only album admin can review.`,
        });
      }

    const cacheKey = `duplicate_images:${albumId}:p${page}:l${limit}:d${
      duplicate || "n"
    }`;

    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.status(200).json(JSON.parse(cached));
    }

    const images = await imageService.getDuplicateImagesService(
      albumId,
      duplicate,
      skip,
      limit
    );
    const response = { page, limit, images };

    await redisClient.set(cacheKey, JSON.stringify(response), "EX", 180);

    console.log("duplicate");
    console.log(images);
    res.status(200).json(response);
  } catch (error) {
    console.error("Error in getImagesController:", error);
    res.status(500).json({ error: "Failed to get images" });
  }
}

async function deleteImageController(req, res) {
  const imageId = req.params.imageId;
  const userId = req.user.id;

  try {
    const image = await imageService.getImageById(imageId);
    if (!image) {
      return res.status(404).json({ error: "Image not found" });
    }
    const albumId = image.album_id;

    const participant = await userModel.getUserAccessRole(albumId, userId);
    if (!participant || participant !== 'admin') {
      return res.status(403).json({ error: "Only album admin can delete image." });
    }

    await imageService.deleteImage(imageId, userId);

    await invalidateAlbumImageCaches(redisClient, albumId);
    await invalidateByPattern(
      redisClient,
      `user_storage_usage:${image.user_id}`
    );
    await invalidateByPattern(
      redisClient,
      `user_storage_usage:${image.user_id}`
    );
    return res.json({ message: "Image deleted successfully" });
  } catch (error) {
    console.error("Error deleting image:", error);
    return res.status(400).json({ error: error.message });
  }
}

async function deleteMultipleImagesController(req, res) {
  const { imageIds } = req.body;
  const userId = req.user?.id;
  

  if (!Array.isArray(imageIds)) {
    return res.status(400).json({ error: "imageIds must be an array" });
  }

  if (!userId) {
    return res.status(401).json({ error: "Authentication required" });
  }

  try {
    const images = await imageService.getImagesByIds(imageIds);
    const albumIds = [...new Set(images.map((img) => img.album_id))];
    const userIds = [...new Set(images.map((img) => img.user_id))];

       // 🔒 Role check for each album
    for (const albumId of albumIds) {
      const participant = await userModel.getUserAccessRole(albumId, userId);

      if (!participant || participant !== 'admin') {
        return res.status(403).json({
          error: `Only album admin can delete images.`,
        });
      }
    }

    const deletedImages = await imageService.deleteMultipleImages(
      imageIds,
      userId
    );

    for (const albumId of albumIds) {
      await invalidateAlbumImageCaches(redisClient, albumId);
    }
    for (const userId of userIds) {
      await invalidateByPattern(redisClient, `user_storage_usage:${userId}`);
    }

    return res.json({
      message: "Images deleted successfully",
      count: deletedImages.length,
      deletedIds: deletedImages.map((img) => img.id),
    });
  } catch (error) {
    console.error("Error deleting images:", error);
    return res.status(500).json({ error: "Failed to delete images" });
  }
}

async function unflagBlurImageController(req, res) {
  const imageId = req.params.imageId;
  const userId = req.user.id;

  try {
    const image = await imageService.getImageById(imageId);
    if (!image) return res.status(404).json({ error: "Image not found" });
    const albumId = image.album_id;

    
       // 🔒 Role check for each album
      const participant = await userModel.getUserAccessRole(albumId, userId);

      if (!participant || participant !== 'admin') {
        return res.status(403).json({
          error: `Only album admin can perform this action.`,
        });
      }

    

    await imageService.unflagBlurImage(imageId, userId);

    await invalidateAlbumImageCaches(redisClient, albumId);

    return res.json({ message: "Blur flag removed successfully" });
  } catch (error) {
    console.error("Error unflagging blur image:", error);
    return res.status(500).json({ error: "Failed to unflag blur image" });
  }
}

async function unflagDuplicateImageController(req, res) {
  const imageId = req.params.imageId;
  const userId = req.user.id;

  try {
    const image = await imageService.getImageById(imageId);
    if (!image) return res.status(404).json({ error: "Image not found" });
    const albumId = image.album_id;

    const participant = await userModel.getUserAccessRole(albumId, userId);
    if (!participant || participant !== 'admin') {
      return res.status(403).json({ error: "Only album admin can perform this action." });
    }

    await imageService.unflagDuplicateImage(imageId, userId);

    await invalidateAlbumImageCaches(redisClient, albumId);

    return res.json({ message: "Duplicate flag removed successfully" });
  } catch (error) {
    console.error("Error unflagging duplicate image:", error);
    return res.status(500).json({ error: "Failed to unflag duplicate image" });
  }
}

async function unflagMultipleBlurImagesController(req, res) {
  const { imageIds } = req.body;
  const userId = req.user.id;

  if (!Array.isArray(imageIds) || imageIds.length === 0) {
    return res
      .status(400)
      .json({ error: "imageIds must be a non-empty array" });
  }

  try {
    const images = await imageService.getImagesByIds(imageIds);
    const albumIds = [...new Set(images.map((img) => img.album_id))];

    
       // 🔒 Role check for each album
    for (const albumId of albumIds) {
      const participant = await userModel.getUserAccessRole(albumId, userId);

      if (!participant || participant !== 'admin') {
        return res.status(403).json({
          error: `Only album admin can perform this action.`,
        });
      }
    }

    const updated = await imageService.unflagMultipleBlurImages(
      imageIds,
      userId
    );

    for (const albumId of albumIds) {
      await invalidateAlbumImageCaches(redisClient, albumId);
    }

    return res.json({
      message: "Blur images unflagged",
      count: updated.length,
    });
  } catch (error) {
    console.error("Error unflagging multiple blur images:", error);
    return res.status(500).json({ error: "Failed to unflag blur images" });
  }
}

async function unflagMultipleDuplicateImagesController(req, res) {
  const { imageIds } = req.body;
  const userId = req.user.id;

  if (!Array.isArray(imageIds) || imageIds.length === 0) {
    return res
      .status(400)
      .json({ error: "imageIds must be a non-empty array" });
  }

  try {
    const images = await imageService.getImagesByIds(imageIds);
    const albumIds = [...new Set(images.map((img) => img.album_id))];

    
    for (const albumId of albumIds) {
      const participant = await userModel.getUserAccessRole(albumId, userId);

      if (!participant || participant !== 'admin') {
        return res.status(403).json({
          error: `Only album admin can perform this action.`,
        });
      }
    }

    const updated = await imageService.unflagMultipleDuplicateImages(
      imageIds,
      userId
    );

    for (const albumId of albumIds) {
      await invalidateAlbumImageCaches(redisClient, albumId);
    }

    return res.json({
      message: "Duplicate images unflagged",
      count: updated.length,
    });
  } catch (error) {
    console.error("Error unflagging multiple duplicate images:", error);
    return res.status(500).json({ error: "Failed to unflag duplicate images" });
  }
}

module.exports = {
  createImageController,
  getImagesController,
  deleteImageController,
  getBlurImagesController,
  getDuplicateImagesController,
  deleteMultipleImagesController,
  unflagBlurImageController,
  unflagDuplicateImageController,
  unflagMultipleBlurImagesController,
  unflagMultipleDuplicateImagesController,
};
