const express = require('express');
const router = express.Router();
const multer = require('multer');
const authController = require('../controllers/authController');
const { authenticateJWT } = require('../middlewares/authMiddleware');
const s3Service=require('../services/s3Service');
const { validateCredentials } = require('../utils/validation');
const storage = multer.memoryStorage();

router.post('/signup/google', authController.googleSignup);
router.post('/login/google', authController.googleLogin);
router.get('/profile', authenticateJWT, authController.getUserProfile);

router.post('/signup', validateCredentials, authController.emailSignup);
router.post('/verify',authController.verifyEmail);
router.post('/login', validateCredentials,authController.emailLogin);
router.put('/update', authenticateJWT, authController.updateProfile);

router.post('/forgot-password',authController.forgotPassword);
router.get('/reset-password', authController.getResetPasswordPage);
router.post('/reset-password', authController.resetPassword);
router.post('/resend-code', authController.resendVerificationCode);
router.post('/updateProfileImage', authenticateJWT,authController.updateProfileImage);
router.get('/storage-stats',authenticateJWT,authController.getUserStorageUsage);

router.post('/profile-presign', authenticateJWT, async (req, res) => {
  try {
    const { fileName, fileType } = req.body;
    const { uploadURL, s3ImageUrl } = await s3Service.generateProfileImageUrl(fileName, fileType, req.user.id);
    return res.status(200).json({ uploadURL, s3ImageUrl });
  } catch (error) {
    console.error('Error generating presigned URL:', error);
    return res.status(500).json({ error: 'Failed to generate presigned URL' });
  }
});

module.exports = router;
