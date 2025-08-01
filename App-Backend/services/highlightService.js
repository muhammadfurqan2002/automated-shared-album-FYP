// services/albumService.js
const albumModel = require('../models/highlightModel');
const geminiService = require('../services/geminiService');

const calculatePagination = (page, limit, totalItems) => {
  const totalPages = Math.ceil(totalItems / limit);
  const offset = (page - 1) * limit;
  
  return {
    currentPage: page,
    totalPages,
    totalItems,
    itemsPerPage: limit,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
    nextPage: page < totalPages ? page + 1 : null,
    previousPage: page > 1 ? page - 1 : null,
    offset
  };
};


const processImageData = (imagesData) => {
  const albumsMap = {};
  
  imagesData.forEach(row => {
    if (!albumsMap[row.album_id]) {
      albumsMap[row.album_id] = [];
    }

    const userNames = row.recognized_users && Array.isArray(row.recognized_users)
      ? row.recognized_users.map(user => user.display_name).filter(name => name)
      : [];

    albumsMap[row.album_id].push({
      url: row.s3_url,
      userNames: userNames
    });
  });

  return albumsMap;
};


const formatImagePath = (s3Url) => {
  const path = s3Url.split('/images/')[1];
  return `images/${path}`;
};


const createAlbumResult = (albumId, imagesData, captions) => {
  const images = imagesData.map(imgData => formatImagePath(imgData.url));
  
  const imageDetails = imagesData.map((imgData, index) => ({
    path: images[index],
    userNames: imgData.userNames
  }));

  return {
    albumId: parseInt(albumId),
    images,
    imageDetails,
    captions
  };
};


const getAlbumImages = async (userId, page = 1, limit = 2) => {
  try {
    const sanitizedPage = Math.max(1, parseInt(page) || 1);
    const sanitizedLimit = limit || 2;

    console.log(`Pagination: page=${sanitizedPage}, limit=${sanitizedLimit}`);

    const totalAlbums = await albumModel.getTotalAlbumCountByUserId(userId);
    const pagination = calculatePagination(sanitizedPage, sanitizedLimit, totalAlbums);

    console.log(`Total albums: ${totalAlbums}, Total pages: ${pagination.totalPages}`);

    const albumIds = await albumModel.getAlbumIdsByUserId(userId, sanitizedLimit, pagination.offset);

    console.log(`Album IDs for page ${sanitizedPage}:`, albumIds);

    if (albumIds.length === 0) {
      return {
        data: [],
        pagination: {
          ...pagination,
          hasNextPage: false,
          hasPreviousPage: sanitizedPage > 1
        }
      };
    }

    const imagesData = await albumModel.getImagesByAlbumIds(albumIds);
    
    const albumsMap = processImageData(imagesData);

    const result = [];
    for (const [albumId, albumImagesData] of Object.entries(albumsMap)) {
      if (albumImagesData.length > 0) {
        if (result.length > 0) {
          await geminiService.sleep(1000);
        }

        console.log(`Processing album ${albumId} with ${albumImagesData.length} images`);
        const captions = await geminiService.generateCaption(albumImagesData);

        console.log(`Album ${albumId} - Generated ${captions.length} captions for ${albumImagesData.length} images:`, captions);
        console.log('Users in images:', albumImagesData.map(img => ({ url: img.url.split('/').pop(), users: img.userNames })));

        if (captions.length !== albumImagesData.length) {
          console.warn(`Caption/Image mismatch in album ${albumId}: ${captions.length} captions vs ${albumImagesData.length} images`);
        }

        const albumResult = createAlbumResult(albumId, albumImagesData, captions);
        result.push(albumResult);
      }
    }

    console.log(`Returning ${result.length} albums for page ${sanitizedPage}`);

    return {
      data: result,
      pagination
    };

  } catch (error) {
    console.error('Error in getAlbumImages service:', error);
    throw error;
  }
};

module.exports = {
  getAlbumImages,
  calculatePagination,
  processImageData,
  formatImagePath,
  createAlbumResult
};