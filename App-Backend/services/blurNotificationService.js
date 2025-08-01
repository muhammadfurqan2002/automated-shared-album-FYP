const Queue = require('bull');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../models/db');
const albumModel = require('../models/albumModel');
const userModel = require('../models/userModel');
const firebaseService = require('./firebaseService');

// Create Bull queue for blur reports
const blurReportQueue = new Queue('blur reports', {
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD || undefined,
  }
});

// Process the blur report queue
blurReportQueue.process('send-blur-report', async (job) => {
  const { albumId } = job.data;

  console.log(`Processing blur report for album ${albumId}`);

  try {
    const album = await albumModel.getAlbumDetails(albumId);
    if (!album) throw new Error(`Album ${albumId} not found`);
    const { album_title: albumTitle, cover_image_url: albumCover } = album;

    const { rows: blurImages } = await pool.query(
      `SELECT id AS image_id, s3_url AS photo_url
         FROM images
        WHERE album_id = $1 AND status = 'blur'`,
      [albumId]
    );
    const count = blurImages.length;

    if (count === 0) {
      console.log(`No blurred images in album ${albumId}`);
      return;
    }

    const title = 'Blur Check Results';
    const message = `Your album "${albumTitle}" has ${count} blurred image${count !== 1 ? 's' : ''}.`;

    // Notify all admins of the album
    const adminResult = await pool.query(`
      SELECT u.id AS user_id, u.fcm_token
      FROM shared_album sa
      JOIN users u ON u.id = sa.user_id
      WHERE sa.album_id = $1 AND sa.access_role = 'admin'
    `, [albumId]);

    for (const admin of adminResult.rows) {
      const notificationId = uuidv4();
      const receiverId = admin.user_id;

      const data = {
        type: 'blur_report',
        notificationId,
        userId: receiverId.toString(),
        albumId: albumId.toString(),
        albumTitle,
        albumCover,
        blurCount: count.toString(),
        createdAt: new Date().toISOString(),
        receiverId: receiverId.toString(),
      };

      await pool.query(
        `INSERT INTO notifications
           ("notificationId", user_id, title, body, data, created_at)
         VALUES ($1,$2,$3,$4,$5,NOW())`,
        [notificationId, receiverId, title, message, data]
      );

      if (admin.fcm_token) {
        await firebaseService.sendPushNotification(
          admin.fcm_token, title, message, data
        );
      }
    }

    console.log(`Successfully sent blur report for album ${albumId}`);
  } catch (error) {
    console.error(`Failed to send blur report for album ${albumId}:`, error);
    throw error;
  }
});

// Function to queue blur report with deduplication
async function queueBlurReport(albumId, delay = 5 * 60 * 1000) {
  const jobId = `blur-report-${albumId}`; // Unique job ID

  await blurReportQueue.add('send-blur-report', {
    albumId
  }, {
    jobId, // This prevents duplicate jobs
    delay,
    attempts: 3,
    backoff: 'exponential',
    removeOnComplete: 10,
    removeOnFail: 5
  });

  console.log(`Queued blur report for album ${albumId}`);
}

module.exports = { queueBlurReport, blurReportQueue };