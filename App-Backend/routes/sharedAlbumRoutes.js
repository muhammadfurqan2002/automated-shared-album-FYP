const express=require('express');
const { authenticateJWT } = require('../middlewares/authMiddleware');
const {createSharedAlbum,getMembersWithDetails,removeUserFromAlbum,checkAccessAndGetAlbum,changeParticipantRole,getSharedImages, generateQrCode, joinAlbumWithToken}=require('../controllers/sharedAlbumController');
const router=express.Router();

router.post('/create-shared-album',authenticateJWT,createSharedAlbum);
router.get('/:albumId/members',authenticateJWT,getMembersWithDetails);
router.delete('/:albumId/:userId',authenticateJWT,removeUserFromAlbum);
router.put('/:albumId/:userId/role',authenticateJWT,changeParticipantRole);
router.get('/:albumId/images',authenticateJWT, getSharedImages);
router.post('/join-with-token',authenticateJWT,joinAlbumWithToken)
router.post('/:id/qr-token',authenticateJWT,generateQrCode)
router.get('/:albumId/check-access',authenticateJWT,checkAccessAndGetAlbum)

module.exports=router;