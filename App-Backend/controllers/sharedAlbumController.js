const dotenv = require("dotenv");
dotenv.config();
const { pool } = require("../models/db");
const albumModel = require("../models/albumModel");
const { v4: uuidv4 } = require("uuid");
const userModel = require("../models/userModel");
const firebaseService = require("../services/firebaseService");
const {
  invalidateByPattern,
  invalidateUserNotificationCache,
} = require("../utils/cache");
const redisClient = require("../utils/redis");
const jwt = require("jsonwebtoken");
const SECRET = process.env.JWT_SECRET;
const TOKEN_EXPIRY_SECONDS = 60 * 10;

const createSharedAlbum = async (req, res) => {
  if (!req.user || !req.user.id) {
    return res.status(401).json({ error: "Authentication required." });
  }

  const client = await pool.connect();

  try {
    const { albumId, participantDetails } = req.body;

    const participant = await userModel.getUserAccessRole(albumId, req.user.id);

    if (!participant || participant !== "admin") {
      return res.status(403).json({
        error: `You don't have access to that album and only admin can share.`,
      });
    }
    if (!albumId || !participantDetails || !Array.isArray(participantDetails)) {
      return res.status(400).json({
        error:
          "Missing required fields. albumId and participantDetails array are required",
      });
    }

    await client.query("BEGIN");

    const albumDetails = await albumModel.getAlbumDetails(albumId);
    if (!albumDetails) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Album not found" });
    }

    const participantPromises = participantDetails.map((participantId) =>
      client.query(
        `INSERT INTO shared_album (album_id, user_id, access_role)
         VALUES ($1, $2, 'viewer')
         ON CONFLICT (album_id, user_id) 
         DO UPDATE SET access_role = 'viewer', updated_at = CURRENT_TIMESTAMP`,
        [albumId, participantId]
      )
    );
    await Promise.all(participantPromises);

    for (const uid of participantDetails) {
      await invalidateByPattern(redisClient, `user_shared_albums:${uid}:*`);
      await invalidateByPattern(redisClient, `user_albums:${uid}:*`);
      await invalidateUserNotificationCache(redisClient, uid);
    }
    await invalidateByPattern(redisClient, `album_members:${albumId}`);
    await invalidateByPattern(redisClient, `suggestions_manual:${albumId}`);

    const users = await userModel.getUsersByIds(participantDetails);

    await sendAlbumSharingNotifications(
      users,
      albumId,
      albumDetails.album_title,
      null,
      albumDetails
    );
    await client.query("COMMIT");

    return res
      .status(200)
      .json({ message: "Shared album created successfully" });
  } catch (error) {
    console.error("Error creating shared album:", error);

    try {
      await client.query("ROLLBACK");
    } catch (rollbackError) {
      console.error("Error rolling back transaction:", rollbackError);
    }

    return res
      .status(500)
      .json({ error: `Failed to create shared album: ${error.message}` });
  } finally {
    client.release();
  }
};

const getMembersWithDetails = async (req, res) => {
  const { albumId } = req.params;
  const userId = req.user.id;
  // Use a unique cache key for each album
  const cacheKey = `album_members:${albumId}`;

  try {
    const participant = await userModel.getUserAccessRole(albumId, userId);

    if (!participant) {
      return res.status(403).json({
        error: `You don't have access to that album.`,
      });
    }
    // Try to get from cache first
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      console.log(`✅ Served album members for albumId ${albumId} from cache`);
      return res.status(200).json(JSON.parse(cached));
    }

    // Otherwise, query the DB
    const result = await pool.query(
      `SELECT u.id AS user_id, 
              u.display_name, 
              u.photo_url,
              u.email, 
              sa.access_role
       FROM shared_album sa
       JOIN users u ON sa.user_id = u.id
       WHERE sa.album_id = $1`,
      [albumId]
    );
    console.log("Members with details:", result.rows);

    if (result.rows.length > 0) {
      const response = {
        albumId,
        members: result.rows,
      };
      // Save to cache for future requests (e.g., 5 min)
      await redisClient.set(cacheKey, JSON.stringify(response), "EX", 300);

      return res.status(200).json(response);
    } else {
      return res
        .status(404)
        .json({ error: "Album not found or no members found" });
    }
  } catch (error) {
    console.error("Error retrieving members with details:", error);
    return res.status(500).json({ error: "Failed to retrieve members" });
  }
};

const removeUserFromAlbum = async (req, res) => {
  const { albumId, userId } = req.params;
  console.log(albumId, userId, "for deletion");
  const client = await pool.connect();

  try {
    const participant = await userModel.getUserAccessRole(albumId, req.user.id);

    if (!participant || participant !== "admin") {
      return res.status(403).json({
        error: `You are not allowed to perform this action.`,
      });
    }
    // 1. Load album details
    const albumDetails = await albumModel.getAlbumDetails(albumId);
    if (!albumDetails) {
      return res.status(404).json({ error: "Album not found" });
    }

    const deleteResult = await client.query(
      `DELETE FROM shared_album
       WHERE album_id = $1
         AND user_id  = $2
       RETURNING *`,
      [albumId, userId]
    );
    if (deleteResult.rowCount === 0) {
      return res.status(404).json({ error: "User not found in this album" });
    }

    await invalidateByPattern(redisClient, `user_shared_albums:${userId}:*`);
    await invalidateByPattern(redisClient, `user_albums:${userId}:*`);
    await invalidateByPattern(redisClient, `album_members:${albumId}`);
    await invalidateByPattern(redisClient, `suggestions_manual:${albumId}`);

    const user = await userModel.findUserById(userId);
    if (user && user.fcm_token) {
      const title = "Album Access Removed";
      const message = `You no longer have access to album "${albumDetails.album_title}"`;
      const notificationId = uuidv4();
      const nowIso = new Date().toISOString();

      const metadata = {
        albumId: albumId.toString(),
        userId: albumDetails.user_id.toString(),
        albumTitle: albumDetails.album_title,
        albumCover: albumDetails.cover_image_url,
        createdAt: nowIso,
        type: "album_access_removed",
        notificationId,
        receiverId: user.id.toString(),
      };

      await firebaseService.sendPushNotification(
        user.fcm_token,
        title,
        message,
        metadata
      );

      await client.query(
        `INSERT INTO notifications
           ("notificationId", user_id, title, body, data, created_at)
         VALUES ($1, $2, $3, $4, $5, NOW())`,
        [notificationId, user.id, title, message, metadata]
      );
    }

    return res
      .status(200)
      .json({ message: "User successfully removed from album" });
  } catch (error) {
    console.error("Error removing user from album:", error);
    return res
      .status(500)
      .json({ error: `Failed to remove user from album: ${error.message}` });
  } finally {
    client.release();
  }
};

const checkAccessAndGetAlbum = async (req, res) => {
  const { albumId } = req.params;
  const userId = req.user.id;
  try {
    const accessQuery = `
      SELECT 1
        FROM shared_album
       WHERE album_id = $1
         AND user_id  = $2
      UNION
      SELECT 1
        FROM albums
       WHERE id       = $1
         AND user_id = $2
    `;
    const accessResult = await pool.query(accessQuery, [albumId, userId]);

    if (accessResult.rowCount === 0) {
      return res.status(403).json({ error: "Access denied to this album" });
    }

    const albumQuery = `
      SELECT
        id,
        user_id,
        album_title,
        cover_image_url,
        created_at
      FROM albums
     WHERE id = $1
    `;
    const albumResult = await pool.query(albumQuery, [albumId]);

    if (albumResult.rowCount === 0) {
      return res.status(404).json({ error: "Album not found" });
    }

    const album = albumResult.rows[0];
    return res.status(200).json(album);
  } catch (err) {
    console.error("Error in checkAccessAndGetAlbum:", err);
    return res.status(500).json({ error: "Server error" });
  }
};

const changeParticipantRole = async (req, res) => {
  const { albumId, userId } = req.params;
  const { newRole } = req.body;

  const client = await pool.connect();

  try {

    const participant = await userModel.getUserAccessRole(albumId, req.user.id);

    if (!participant || participant !== "admin") {
      return res.status(403).json({
        error: `You are not allowed to perform this action.`,
      });
    }
    const albumDetails = await albumModel.getAlbumDetails(albumId);
    if (!albumDetails) {
      return res.status(404).json({ error: "Album not found" });
    }

    const result = await client.query(
      `SELECT * FROM shared_album WHERE album_id = $1 AND user_id = $2`,
      [albumId, userId]
    );

    console.log("Result of checking user in album:", result);
    if (result.rowCount === 0) {
      return res.status(404).json({ error: "User not found in this album" });
    }

    await client.query(
      `UPDATE shared_album 
       SET access_role = $1, updated_at = CURRENT_TIMESTAMP
       WHERE album_id = $2 AND user_id = $3`,
      [newRole, albumId, userId]
    );

    await invalidateByPattern(redisClient, `user_shared_albums:${userId}:*`);
    await invalidateByPattern(redisClient, `album_members:${albumId}`);

    const user = await userModel.findUserById(userId);
    console.log(user);
    if (user && user.fcm_token) {
      const title = "Album Role Updated";
      const message = `Your role in the album "${albumDetails.album_title}" has been updated to "${newRole}".`;
      const notificationUUID = uuidv4();
      const metadata = {
        albumId: albumId,
        userId: albumDetails.user_id.toString(),
        albumTitle: albumDetails.album_title.toString(),
        albumCover: albumDetails.cover_image_url.toString(),
        createdAt: new Date(albumDetails.created_at).toISOString(),
        type: "album_role_updated",
        notificationId: notificationUUID,
        receiverId: user.id.toString(),
      };
      await firebaseService.sendPushNotification(
        user.fcm_token,
        title,
        message,
        metadata
      );

      await client.query(
        `INSERT INTO notifications ("notificationId", user_id, title, body, data, created_at)
         VALUES ($1, $2, $3, $4, $5, NOW())`,
        [notificationUUID, user.id, title, message, metadata]
      );
    }

    return res
      .status(200)
      .json({ message: `Role updated to "${newRole} successfully"` });
  } catch (error) {
    console.error("Error changing participant role:", error);
    return res
      .status(500)
      .json({ error: `Failed to change role: ${error.message}` });
  } finally {
    client.release();
  }
};

const getSharedImages = async (req, res) => {
  const { albumId } = req.params;
  const userId = req.user.id;
  if (!userId) {
    return res
      .status(401)
      .json({ error: "You must be logged in to access this resource." });
  }
  const duplicate = req.query.duplicate || "any";
  const status = req.query.status || "all";
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const offset = (page - 1) * limit;

  const cacheKey = `shared_images:${albumId}:u${userId}:p${page}:l${limit}:d${duplicate}:s${status}`;

  try {

    
    const participant = await userModel.getUserAccessRole(albumId,userId);

    if (!participant) {
      return res.status(403).json({
        error: `You don't have access to that album.`,
      });
    }
    
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.status(200).json(JSON.parse(cached));
    }

    const albumDetails = await albumModel.getAlbumDetails(albumId);
    if (!albumDetails) {
      return res.status(404).json({ error: "Album not found" });
    }

    const client = await pool.connect();

    try {
      const recognitionResults = await client.query(
        `SELECT image_id 
         FROM face_recognition_results 
         WHERE album_id = $1 AND user_id = $2`,
        [albumId, userId]
      );
      const matchedImageIds = recognitionResults.rows.map(
        (row) => row.image_id
      );

      if (matchedImageIds.length === 0) {
        return res
          .status(404)
          .json({ error: "No matching images found for the given criteria" });
      }

      const images = await client.query(
        `SELECT * 
         FROM images 
         WHERE id = ANY($1::int[]) AND duplicate = $2 AND status = $3
         ORDER BY id DESC
         OFFSET $4 LIMIT $5`,
        [matchedImageIds, duplicate, status, offset, limit]
      );

      console.log(images);

      const response = {
        albumId,
        page,
        limit,
        total: matchedImageIds.length,
        images: images.rows,
      };

      await redisClient.set(cacheKey, JSON.stringify(response), "EX", 180);

      return res.status(200).json(response);
    } finally {
      client.release();
    }
  } catch (error) {
    console.error("Error retrieving shared images:", error);
    return res
      .status(500)
      .json({ error: `Failed to retrieve shared images: ${error.message}` });
  }
};

const generateQrCode = async (req, res) => {
  const albumId = req.params.id;

  const payload = {
    albumId: Number(albumId),
    exp: Math.floor(Date.now() / 1000) + TOKEN_EXPIRY_SECONDS,
  };

  const token = jwt.sign(payload, SECRET);

  await redisClient.setEx(
    `qr_token:${token}`,
    TOKEN_EXPIRY_SECONDS,
    albumId.toString()
  );

  res.status(200).json({ token });
};

const joinAlbumWithToken = async (req, res) => {
  if (!req.user?.id) {
    return res.status(401).json({ error: "Authentication required" });
  }

  const userId = req.user.id;
  const { token } = req.body;

  if (!token) {
    return res.status(400).json({ error: "QR token is required" });
  }

  let albumId;

  try {
    const decoded = jwt.verify(token, SECRET);
  } catch (err) {
    return res.status(400).json({ error: "Invalid or expired QR token" });
  }

  albumId = await redisClient.getDel(`qr_token:${token}`);
  if (!albumId) {
    return res.status(400).json({ error: "QR already used or expired" });
  }

  const client = await pool.connect();

  try {
    const albumDetails = await albumModel.getAlbumDetails(albumId);
    if (!albumDetails) {
      return res.status(404).json({ error: "Album not found" });
    }

    const { rowCount } = await client.query(
      `SELECT 1 FROM shared_album WHERE album_id = $1 AND user_id = $2`,
      [albumId, userId]
    );
    if (rowCount > 0) {
      const freshAlbum = await albumModel.getAlbumDetails(albumId);
      return res
        .status(200)
        .json({ album: freshAlbum, message: "Already joined" });
    }

    await client.query("BEGIN");
    await client.query(
      `INSERT INTO shared_album (album_id, user_id, access_role)
       VALUES ($1, $2, 'viewer')`,
      [albumId, userId]
    );

    await invalidateByPattern(redisClient, `user_shared_albums:${userId}:*`);
    await invalidateByPattern(redisClient, `album_members:${albumId}`);
    await invalidateByPattern(redisClient, `suggestions_manual:${albumId}`);

    await client.query("COMMIT");

    const freshAlbum = await albumModel.getAlbumDetails(albumId);
    return res.status(200).json({ album: freshAlbum });
  } catch (err) {
    console.error("joinAlbumWithToken error:", err);
    await client.query("ROLLBACK").catch(() => {});
    return res.status(500).json({ error: "Failed to join album" });
  } finally {
    client.release();
  }
};

const sendAlbumSharingNotifications = async (
  users,
  albumId,
  albumTitle,
  adminId,
  albumDetails
) => {
  const client = await pool.connect();

  try {
    const notificationPromises = users
      .filter((user) => user.fcm_token)
      .map(async (user) => {
        const isAdmin = user.id === adminId;
        const title = isAdmin ? "Album Created" : "New Shared Album";
        const message = isAdmin
          ? `You've created the album "${albumTitle}"`
          : `"${albumTitle}" has been shared with you`;

        const notificationUUID = uuidv4();
        const metadata = {
          albumId: albumId.toString(),
          userId: albumDetails.user_id.toString(),
          albumTitle: albumDetails.album_title.toString(),
          albumCover: albumDetails.cover_image_url.toString(),
          createdAt: new Date(albumDetails.created_at).toISOString(),
          type: isAdmin ? "album_created" : "album_shared",
          receiverId: user.id.toString(),
          notificationId: notificationUUID,
        };

        try {
          await firebaseService.sendPushNotification(
            user.fcm_token,
            title,
            message,
            metadata
          );

          await client.query(
            `INSERT INTO notifications ("notificationId", user_id, title, body, data, created_at)
             VALUES ($1, $2, $3, $4, $5, NOW())`,
            [notificationUUID, user.id, title, message, metadata]
          );

          await invalidateUserNotificationCache(redisClient, user.id);
        } catch (err) {
          console.error(`Failed to notify user ${user.id}:`, err);
        }
      });

    await Promise.all(notificationPromises);
  } finally {
    client.release();
  }
};

module.exports = {
  createSharedAlbum,
  sendAlbumSharingNotifications,
  getMembersWithDetails,
  removeUserFromAlbum,
  changeParticipantRole,
  getSharedImages,
  joinAlbumWithToken,
  generateQrCode,
  checkAccessAndGetAlbum,
};
