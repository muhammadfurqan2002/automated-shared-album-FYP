const express = require('express');
const { authenticateJWT } = require('../middlewares/authMiddleware');
const highlightController = require('../controllers/highlightController');
const router = express.Router();

router.get('/',authenticateJWT,highlightController.getAlbumImages);
router.post('/',authenticateJWT,highlightController.downloadHighlights);




module.exports = router;