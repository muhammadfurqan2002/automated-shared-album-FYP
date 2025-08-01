const Queue = require('bull');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../models/db');
const albumModel = require('../models/albumModel');
const firebaseService = require('./firebaseService');

// Create Bull queue
const faceReportQueue = new Queue('face reports', {
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD || undefined,
  }
});

faceReportQueue.process('send-face-report', async (job) => {
  const { albumId } = job.data;

  console.log(`Processing face recognition report for album ${albumId}`);

  try {
    const album = await albumModel.getAlbumDetails(albumId);
    if (!album) throw new Error(`Album ${albumId} not found`);

    const { album_title: albumTitle, cover_image_url: albumCover } = album;

    // Get count of distinct recognized users who are NOT part of shared_album
    const { rows } = await pool.query(
      `SELECT DISTINCT fr.user_id
         FROM face_recognition_results fr
        WHERE fr.album_id = $1
          AND fr.user_id IS NOT NULL
          AND fr.user_id NOT IN (
              SELECT sa.user_id
              FROM shared_album sa
              WHERE sa.album_id = $1
          )`,
      [albumId]
    );

    const count = rows.length;
    if (count === 0) {
      console.log(`No unshared recognized users for album ${albumId}`);
      return;
    }

    // Notify all admins
    const adminTitle = 'Face Recognition Complete';
    const adminMessage = `Face recognition identified ${count} user${count !== 1 ? 's' : ''} (not part of the album) in your album "${albumTitle}".`;

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
        type: 'face_recognition_report',
        notificationId,
        userId: receiverId.toString(),
        albumId: albumId.toString(),
        albumTitle,
        albumCover,
        recognizedCount: count.toString(),
        createdAt: new Date().toISOString(),
        receiverId: receiverId.toString(),
      };

      await pool.query(`
        INSERT INTO notifications
          ("notificationId", user_id, title, body, data, created_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
      `, [notificationId, receiverId, adminTitle, adminMessage, data]);

      if (admin.fcm_token) {
        await firebaseService.sendPushNotification(admin.fcm_token, adminTitle, adminMessage, data);
      }
    }

    // Notify non-admin users (viewers)
    const viewerTitle = 'New Images Added';
    const viewerMessage = `New images have been added to the album "${albumTitle}".`;

    const viewerResult = await pool.query(`
      SELECT u.id AS user_id, u.fcm_token
      FROM shared_album sa
      JOIN users u ON u.id = sa.user_id
      WHERE sa.album_id = $1 AND sa.access_role != 'admin'
    `, [albumId]);

    for (const viewer of viewerResult.rows) {
      const notificationId = uuidv4();
      const receiverId = viewer.user_id;

      const data = {
        type: 'new_images_added',
        notificationId,
        userId: receiverId.toString(),
        albumId: albumId.toString(),
        albumTitle,
        albumCover,
        createdAt: new Date().toISOString(),
        receiverId: receiverId.toString(),
      };

      await pool.query(`
        INSERT INTO notifications
          ("notificationId", user_id, title, body, data, created_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
      `, [notificationId, receiverId, viewerTitle, viewerMessage, data]);

      if (viewer.fcm_token) {
        await firebaseService.sendPushNotification(viewer.fcm_token, viewerTitle, viewerMessage, data);
      }
    }

    console.log(`Successfully sent face recognition and viewer notifications for album ${albumId}`);
  } catch (error) {
    console.error(`Failed to send face report for album ${albumId}:`, error);
    throw error;
  }
});

async function queueFaceRecognitionReport(albumId, delay = 60 * 1000) {
  const jobId = `face-report-${albumId}`;
  await faceReportQueue.add('send-face-report', { albumId }, {
    jobId,
    delay,
    attempts: 3,
    backoff: 'exponential',
    removeOnComplete: true,
    removeOnFail: true,
  });

  console.log(`Queued face recognition report for album ${albumId}`);
}

module.exports = {
  queueFaceRecognitionReport,
  faceReportQueue,
};
