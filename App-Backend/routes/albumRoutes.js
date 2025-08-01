const express = require('express');
const { authenticateJWT } = require('../middlewares/authMiddleware');
const {
  createAlbumController,
  getAlbumsController,
  updateAlbumController,
  deleteAlbumController,
  getSuggestions,
  getSharedAlbumsController,
  getSuggestionsManually
} = require('../controllers/albumController');
const s3Service = require('../services/s3Service');  

const router = express.Router();

router.post('/', authenticateJWT, createAlbumController);
router.get('/', authenticateJWT, getAlbumsController);
router.get('/shared-albums', authenticateJWT, getSharedAlbumsController);
router.put('/:albumId', authenticateJWT, updateAlbumController);
router.delete('/:albumId', authenticateJWT, deleteAlbumController);
router.get('/get-suggestions',authenticateJWT,getSuggestions)
router.get('/get-suggestions-manually',authenticateJWT,getSuggestionsManually)
router.post('/cover-presign', authenticateJWT, async (req, res) => {
  try {
    const { fileName, fileType } = req.body;
    const { uploadURL, s3ImageUrl } = await s3Service.generateAlbumCoverUrl(fileName, fileType, req.user.id);
    return res.status(200).json({ uploadURL, s3ImageUrl });
  } catch (error) {
    console.error('Error generating presigned URL:', error);
    return res.status(500).json({ error: 'Failed to generate presigned URL' });
  }
});

module.exports = router;
