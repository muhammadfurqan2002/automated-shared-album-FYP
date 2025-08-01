const albumModel = require('../models/albumModel');
const s3Service = require('../services/s3Service');

async function createAlbumService({ userId, albumTitle, coverImageUrl }) {
  console.log('Final coverImageUrl:', coverImageUrl);
  return await albumModel.createAlbum({ userId, albumTitle, coverImageUrl });
}
async function getAlbumsService(userId, offset = 0, limit = 10) {
  return await albumModel.getAlbumsByUser(userId, offset, limit);
}

async function getAlbumsCount(userId) {
  return await albumModel.getAlbumsCountByUser(userId);
}


async function updateAlbumService({ albumId, albumTitle,coverImageUrl }) {
  return await albumModel.updateAlbum({ albumId, albumTitle, coverImageUrl });
}

async function deleteAlbumService(albumId) {
  return await albumModel.deleteAlbum(albumId);
}




async function getSharedAlbumsService(userId, limit = 10, offset = 0) {
  return await albumModel.getSharedAlbumsByUser(userId, limit, offset);
}

async function getSharedAlbumsCount(userId) {
  return await albumModel.getSharedAlbumsCountByUser(userId);
}


module.exports = {
  createAlbumService,
  getAlbumsService,
  updateAlbumService,
  deleteAlbumService,
  getSharedAlbumsService,
  getAlbumsCount,
  getSharedAlbumsCount
};
