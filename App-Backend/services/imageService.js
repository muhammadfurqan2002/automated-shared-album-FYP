const imageModel = require('../models/imageModel');
const s3Service = require('../services/s3Service');

async function createImageService({ albumId, userId, fileName, s3ImageUrl }) {
  return await imageModel.createImage({ albumId, userId, fileName, s3Url: s3ImageUrl });
}

async function getImagesService(albumId,duplicate,status, skip, limit = 10) {
  return await imageModel.getImagesByAlbum(albumId,duplicate,status,skip, limit);
}
async function getBlurImagesService(albumId,status, skip, limit = 10) {
  return await imageModel.getBlurImagesByAlbum(albumId,status,skip, limit);
}
async function getDuplicateImagesService(albumId,duplicate, skip, limit = 10) {
  return await imageModel.getDuplicateImagesByAlbum(albumId,duplicate,skip, limit);
}

async function deleteImage(imageId, userId) {
  const image = await imageModel.getImageById(imageId);
  if (!image) {
    throw new Error('Image not found');
  }
  const s3Key = `images/${img.album_id}/${img.user_id}/${img.file_name}`;
  await s3Service.deleteFromS3(s3Key);
  await imageModel.deleteImageById(imageId);

  return { success: true };
}
async function deleteMultipleImages(imageIds, userId) {
  if (!Array.isArray(imageIds) || imageIds.length === 0) {
    return [];
  }
  
  const images = await imageModel.getImagesByIds(imageIds);

  const userIds = images.map(img => img.user_id);
  
 
  for (const img of userIds) {
    try {
      const s3Key = `images/${img.album_id}/${img.user_id}/${img.file_name}`;
      await s3Service.deleteFromS3(s3Key);
    } catch (error) {
      console.error(`Failed to delete image ${img.id} from S3:`, error);
    }
  }

  const deletedImages = await imageModel.deleteImagesByIds(imageIds);
  return deletedImages;
}

async function unflagBlurImage(imageId, userId) {
  const image = await imageModel.getImageById(imageId);
  if (!image) throw new Error('Image not found');

  return await imageModel.updateImageToUnflagBlur(imageId);
}

async function unflagDuplicateImage(imageId, userId) {
  const image = await imageModel.getImageById(imageId);
  if (!image) throw new Error('Image not found');


  return await imageModel.updateImageToUnflagDuplicate(imageId);
}


async function unflagMultipleBlurImages(imageIds, userId) {
  return await imageModel.unflagBlurImagesByIds(imageIds);
}

async function unflagMultipleDuplicateImages(imageIds, userId) {
  return await imageModel.unflagDuplicateImagesByIds(imageIds);
}

async function getImageById(imageId) {
  return await imageModel.getImageById(imageId);
}

async function getImagesByIds(imageIds) {
  return await imageModel.getImagesByIds(imageIds);
}


module.exports = {
  createImageService,
  getImagesService,
  deleteImage,
  getBlurImagesService,
  getDuplicateImagesService,
  deleteMultipleImages,
  unflagBlurImage,
  unflagDuplicateImage,
  unflagMultipleBlurImages,
  unflagMultipleDuplicateImages,
  getImageById,
  getImagesByIds
};
