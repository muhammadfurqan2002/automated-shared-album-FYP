const dotenv = require('dotenv');
dotenv.config();
const AWS = require('aws-sdk');
const {pool} = require('../models/db');


const s3 = new AWS.S3({
  region: process.env.AWS_REGION,
});

function parseS3Url(url) {
  try {
    const match = url.match(/^https?:\/\/([^.]*)\.s3\.amazonaws\.com\/(.+)$/);
    if (!match) throw new Error(`Invalid S3 URL: ${url}`);
    
    return {
      Bucket: match[1],
      Key: decodeURIComponent(match[2]),
    };
  } catch (err) {
    console.error(`parseS3Url error: ${err.message}`);
    throw err;
  }
}


async function getObjectSize(url) {
  try {
    const { Bucket, Key } = parseS3Url(url);
    const head = await s3.headObject({ Bucket, Key }).promise();
    return head.ContentLength || 0;
  } catch (err) {
    console.error(`Error getting size for URL: ${url}`);
    console.error(`Message: ${err.message}`);
    console.error(`Full error:`, err);
    return 0;
  }
}

async function getUserStorageStats(userId) {
  const result = await pool.query(`
    SELECT s3_url AS url, 'image' AS type FROM images WHERE user_id = $1
    UNION ALL
    SELECT cover_image_url AS url, 'album' AS type FROM albums WHERE user_id = $1
  `, [userId]);

  const urls = result.rows.map(r => r.url);
  const sizes = await Promise.all(urls.map(getObjectSize));
  const totalBytes = sizes.reduce((sum, b) => sum + b, 0);
  const memoryUsedMB = (totalBytes / (1024 * 1024)).toFixed(2);

  const totalImages = result.rows.filter(r => r.type === 'image').length;
  const totalAlbums = result.rows.filter(r => r.type === 'album').length;

  return {
    totalImages,
    totalAlbums,
    memoryUsedMB: Number(memoryUsedMB),
  };
}

module.exports = { getUserStorageStats };