const albumService = require("../services/albumService");
const batchService = require("../services/batchService");
const { pool } = require("../models/db");
const redisClient = require("../utils/redis");
const userModel = require("../models/userModel");
const {
  invalidateAlbumImageCaches,
  invalidateAllUserAlbumCaches,
  invalidateByPattern,
} = require("../utils/cache");

async function createAlbumController(req, res) {
  try {
    const { albumTitle, coverImageUrl } = req.body;
    if (!coverImageUrl) {
      return res.status(400).json({ error: "coverImageUrl is required" });
    }
    const album = await albumService.createAlbumService({
      userId: req.user.id,
      albumTitle,
      coverImageUrl,
    });
    await pool.query(
      `INSERT INTO shared_album (album_id, user_id, access_role)
       VALUES ($1, $2, 'admin')
       ON CONFLICT (album_id, user_id)
       DO UPDATE SET access_role = 'admin', updated_at = CURRENT_TIMESTAMP`,
      [album.id, req.user.id]
    );

    const userId = req.user.id;
    await invalidateByPattern(redisClient, `user_albums:${userId}:*`);
    await invalidateByPattern(redisClient, `user_shared_albums:${userId}:*`);
    await invalidateByPattern(redisClient, `album_members:${album.id}`);
    await invalidateByPattern(redisClient, `user_storage_usage:${userId}`);
    res.status(201).json(album);
  } catch (error) {
    console.error("Error in createAlbumController:", error);
    res.status(500).json({ error: "Failed to create album" });
  }
}

async function getAlbumsController(req, res) {
  const userId = req.user.id;
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 10;
  const offset = (page - 1) * limit;

  const cacheKey = `user_albums:${userId}:p${page}:l${limit}`;

  try {
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.status(200).json(JSON.parse(cached));
    }

    const albums = await albumService.getAlbumsService(userId, offset, limit);

    // Optionally, return total count for frontend pagination controls:
    const totalAlbums = await albumService.getAlbumsCount(userId);

    console.log(
      "limit:",
      limit,
      "page:",
      page,
      "offset:",
      offset,
      "returned:",
      albums.length
    );
    console.log(albums);

    const response = {
      page,
      limit,
      total: totalAlbums,
      albums,
    };

    await redisClient.set(cacheKey, JSON.stringify(response), "EX", 300);

    return res.status(200).json(response);
  } catch (error) {
    console.error("Error in getAlbumsController:", error);
    res.status(500).json({ error: "Failed to get albums" });
  }
}

async function getSharedAlbumsController(req, res) {
  const userId = req.user.id;
  const page = parseInt(req.query.page, 10) || 1;
  const limit = parseInt(req.query.limit, 10) || 10;
  const offset = (page - 1) * limit;
  const cacheKey = `user_shared_albums:${userId}:p${page}:l${limit}`;

  try {
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.status(200).json(JSON.parse(cached));
    }

    const total = await albumService.getSharedAlbumsCount(userId);

    const albums = await albumService.getSharedAlbumsService(
      userId,
      limit,
      offset
    );

    const response = { page, limit, total, albums };

    await redisClient.set(cacheKey, JSON.stringify(response), "EX", 300);

    return res.status(200).json(response);
  } catch (error) {
    console.error("Error in getSharedAlbumsController:", error);
    res.status(500).json({ error: "Failed to get shared albums" });
  }
}

async function updateAlbumController(req, res) {
  try {
    const { albumId, albumTitle, coverImageUrl } = req.body;

    const participant = await userModel.getUserAccessRole(albumId, req.user.id);

    if (!participant || participant !== "admin") {
      return res.status(403).json({
        error: `You can't update album,Try later.`,
      });
    }
    const album = await albumService.updateAlbumService({
      albumId,
      albumTitle,
      coverImageUrl,
    });

    await invalidateAllUserAlbumCaches(redisClient, albumId);
    await invalidateAlbumImageCaches(redisClient, albumId);
    await redisClient.del(`suggestions_manual:${albumId}`);

    res.status(200).json(album);
  } catch (error) {
    console.error("Error in updateAlbumController:", error);
    res.status(500).json({ error: "Failed to update album" });
  }
}

async function deleteAlbumController(req, res) {
  try {
    const { albumId } = req.params;

    const participant = await userModel.getUserAccessRole(albumId, req.user.id);

    if (!participant || participant !== "admin") {
      return res.status(403).json({
        error: `You can't delete album,Try later.`,
      });
    }

    await invalidateAlbumImageCaches(redisClient, albumId);
    await invalidateAllUserAlbumCaches(redisClient, albumId);
    await redisClient.del(`suggestions_manual:${albumId}`);

    const album = await albumService.deleteAlbumService(albumId);

    await invalidateByPattern(redisClient, `user_storage_usage:${req.user.id}`);
    res.status(200).json(album);
  } catch (error) {
    console.error("Error in deleteAlbumController:", error);
    res.status(500).json({ error: "Failed to delete album" });
  }
}

const getSuggestions = async (req, res) => {
  try {
    const { albumId } = req.query;
    if (!albumId) {
      return res.status(400).json({ error: "Missing albumId" });
    }

    const participant = await userModel.getUserAccessRole(albumId,req.user.id);

    if (!participant || participant !== "admin") {
      return res.json({
        message: "You don't have permission to get suggestions.",
        details: { albumId, timestamp: new Date().toISOString() },
      });
    }

    const storedResults = await batchService.getRecognitionResults(albumId);

    console.log("Recognition Result After Completing single batch");
    console.log(storedResults);

    if (!storedResults || storedResults.length === 0) {
      return res.json({
        message: "No processing results yet—check back soon!",
        details: { albumId, timestamp: new Date().toISOString() },
      });
    }

    const detectedUserMap = new Map();
    storedResults.forEach((result) => {
      if (result.user_id && !detectedUserMap.has(result.user_id)) {
        detectedUserMap.set(result.user_id, {
          albumId: result.albumId,
          userId: result.user_id,
          // photoUrl: result.photo_url,
          photoUrl: result.photo_urls.front,
        });
      }
    });
    const detectedUserIds = [...detectedUserMap.keys()];

    const sharedMembersRes = await pool.query(
      `SELECT user_id FROM shared_album WHERE album_id = $1`,
      [albumId]
    );
    const sharedUserIds = new Set(
      sharedMembersRes.rows.map((row) => row.user_id)
    );

    const newDetectedUsers = detectedUserIds
      .filter((uid) => !sharedUserIds.has(uid))
      .map((uid) => detectedUserMap.get(uid));

    const totalMatches = newDetectedUsers.length;
    const suggestion =
      totalMatches > 0
        ? `We found ${totalMatches} new user${
            totalMatches > 1 ? "s" : ""
          } to tag!`
        : "No new faces to tag—try adding more photos!";

    res.status(200).json({
      suggestion,
      details: newDetectedUsers,
      totalMatches,
    });
  } catch (error) {
    console.error("Error generating suggestions:", error);
    res.status(500).json({
      error: "Failed to generate suggestions",
      details: error.toString(),
    });
  }
};

const getSuggestionsManually = async (req, res) => {
  try {
    const { albumId } = req.query;
    if (!albumId) {
      return res.status(400).json({ error: "Missing albumId" });
    }

    const participant = await userModel.getUserAccessRole(albumId, req.user.id);

    if (!participant || participant !== "admin") {
      return res.status(403).json({
        error: `Only admin can get suggestions.`,
      });
    }

    const cacheKey = `suggestions_manual:${albumId}`;
    // Try cache first
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.status(200).json(JSON.parse(cached));
    }

    const usersFromFaceRecognition = await pool.query(
      `SELECT DISTINCT user_id FROM face_recognition_results WHERE album_id = $1`,
      [albumId]
    );

    if (usersFromFaceRecognition.rows.length === 0) {
      const emptyResponse = {
        suggestion: "No faces detected yet—try adding more photos!",
        details: [],
        totalMatches: 0,
      };
      await redisClient.set(cacheKey, JSON.stringify(emptyResponse), "EX", 300); // cache empty too
      return res.status(200).json(emptyResponse);
    }

    const sharedAlbumUsers = await pool.query(
      `SELECT user_id FROM shared_album WHERE album_id = $1`,
      [albumId]
    );

    const sharedUserIds = new Set(
      sharedAlbumUsers.rows.map((user) => user.user_id)
    );

    const filteredUsers = usersFromFaceRecognition.rows.filter(
      (user) => !sharedUserIds.has(user.user_id)
    );

    if (filteredUsers.length === 0) {
      const noNewResponse = {
        suggestion: "No new faces to tag—try adding more photos!",
        details: [],
        totalMatches: 0,
      };
      await redisClient.set(cacheKey, JSON.stringify(noNewResponse), "EX", 300);
      return res.status(200).json(noNewResponse);
    }

    const userDetailsPromises = filteredUsers.map(async (user) => {
      const userDetails = await pool.query(
        `
        SELECT id, email, display_name, photo_url 
        FROM users WHERE id = $1
      `,
        [user.user_id]
      );
      return userDetails.rows[0];
    });

    const userDetails = await Promise.all(userDetailsPromises);

    console.log(userDetails);

    const responseDetails = userDetails.map((user) => ({
      albumId,
      userId: user.id,
      email: user.email,
      display_name: user.display_name,
      photoUrl: user.photo_url,
    }));

    const response = {
      suggestion: `We found ${filteredUsers.length} new user${
        filteredUsers.length > 1 ? "s" : ""
      } to tag!`,
      details: responseDetails,
      totalMatches: filteredUsers.length,
    };

    await redisClient.set(cacheKey, JSON.stringify(response), "EX", 300);

    res.status(200).json(response);
  } catch (error) {
    console.error("Error generating suggestions:", error);
    res.status(500).json({
      error: "Failed to generate suggestions",
      details: error.toString(),
    });
  }
};

module.exports = {
  createAlbumController,
  getAlbumsController,
  updateAlbumController,
  deleteAlbumController,
  getSuggestions,
  getSharedAlbumsController,
  getSuggestionsManually,
};
