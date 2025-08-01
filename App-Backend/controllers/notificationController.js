const { pool } = require('../models/db');
const {invalidateUserNotificationCache}=require("../utils/cache")
const redisClient=require('../utils/redis');
const getAllNotifications = async (req, res) => {
  const user_id = req.user.id;
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const offset = (page - 1) * limit;
  const cacheKey = `notifications:${user_id}:p${page}:l${limit}`;

  try {
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.status(200).json(JSON.parse(cached));
    }

    const result = await pool.query(
      `SELECT * FROM notifications
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
      [user_id, limit, offset]
    );

    await redisClient.set(cacheKey, JSON.stringify(result.rows), 'EX', 180);

    res.status(200).json(result.rows);
  } catch (err) {
    console.error('Error fetching notifications:', err);
    res.status(500).json({ message: 'Internal server error' });
  }
};


const deleteNotification = async (req, res) => {
  const user_id = req.user.id;
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM notifications WHERE "notificationId" = $1 AND user_id = $2', [id, user_id]);
    await invalidateUserNotificationCache(redisClient, user_id);
    res.status(200).json({ message: 'Notification deleted' });
  } catch (err) {
    console.error('Error deleting notification:', err);
    res.status(500).json({ message: 'Internal server error' });
  }
};

const clearAllNotifications = async (req, res) => {
  const user_id = req.user.id;
  try {
    await pool.query(`DELETE FROM notifications WHERE user_id = $1`, [user_id]);
    await invalidateUserNotificationCache(redisClient, user_id);
    res.status(200).json({ message: 'All notifications cleared' });
  } catch (err) {
    console.error('Error clearing notifications:', err);
    res.status(500).json({ message: 'Internal server error' });
  }
};

module.exports = {
  getAllNotifications,
  deleteNotification,
  clearAllNotifications
};
