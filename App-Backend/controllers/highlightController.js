const albumService = require('../services/highlightService');
const fs = require('fs-extra');
const path = require('path');
const ffmpeg = require('fluent-ffmpeg');
const { v4: uuidv4 } = require('uuid');
const axios = require('axios');
const { validateVideoRequest } = require('../models/videoModel.js');
const { createVideo } = require('./videoController.js');

const TMP_BASE = path.join('./tmp');
const AUDIO_BASE = path.join('./audio');
fs.ensureDirSync(TMP_BASE);
fs.ensureDirSync(AUDIO_BASE);


const dependencies = { axios, fs, ffmpeg, path };

const getAlbumImages = async (req, res) => {
  try {
    const userId = req.user.id;
    
    const page = req.query.page;
    const limit = 2;
    console.log(`Controller: Processing request for user ${userId}, page ${page}`);

    const result = await albumService.getAlbumImages(userId, page, limit);

    return res.status(200).json(result);

  } catch (error) {
    console.error('Error in getAlbumImages controller:', error);
    
    return res.status(500).json({ 
      error: error.message || 'Internal server error',
      pagination: null
    });
  }
};

const downloadHighlights=async (req, res) => {
  const validation = validateVideoRequest(req.body);
  if (!validation.isValid) {
    return res.status(400).json({ error: validation.error });
  }

  const jobId = uuidv4();
  const tempDir = path.join(TMP_BASE, jobId);
  await fs.ensureDir(tempDir);

  try {
    console.log(`Starting video creation job ${jobId} with ${req.body.images.length} images`);
    const outputVideo = await createVideo(
      req.body,
      tempDir,
      AUDIO_BASE,
      dependencies
    );

    res.status(200).download(outputVideo, 'output.mp4', (err) => {
      if (err) {
        console.error('Error sending file:', err);
      }
      setTimeout(() => {
        fs.remove(tempDir).catch(console.error);
      }, 5000);
    });

  } catch (err) {
    console.error(`[ERROR] Job ${jobId}:`, err);

    fs.remove(tempDir).catch(console.error);

    res.status(500).json({
      error: err.message,
      jobId: jobId
    });
  }
};


module.exports = {
  getAlbumImages,
  downloadHighlights
};