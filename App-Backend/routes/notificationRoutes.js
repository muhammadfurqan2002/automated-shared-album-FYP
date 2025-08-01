// notificationRoutes.js
const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const { authenticateJWT } = require('../middlewares/authMiddleware');

router.get('/', authenticateJWT,notificationController.getAllNotifications);
router.delete('/:id', authenticateJWT,notificationController.deleteNotification);
router.post('/user',authenticateJWT ,notificationController.clearAllNotifications);

module.exports = router;
