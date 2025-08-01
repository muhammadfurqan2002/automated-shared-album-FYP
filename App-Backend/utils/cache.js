const {pool}=require('../models/db')
async function invalidateAlbumImageCaches(redisClient, albumId) {
  const patterns = [
    `album_images:${albumId}:*`,
    `blur_images:${albumId}:*`,
    `duplicate_images:${albumId}:*`,
    `shared_images:${albumId}:*`
  ];
  for (const pattern of patterns) {
    const keys = await redisClient.keys(pattern);
    if (keys.length) {
      await redisClient.del(...keys);
      console.log("invalidated all types of images",keys)
    }
  }
}

async function invalidateBlurCache(redisClient, albumId) {
  const keys = await redisClient.keys(`blur_images:${albumId}:*`);
  if (keys.length) await redisClient.del(...keys);
}
async function invalidateDuplicateCache(redisClient, albumId) {
  const keys = await redisClient.keys(`duplicate_images:${albumId}:*`);
  if (keys.length) await redisClient.del(...keys);
}
async function invalidateAlbumImagesCache(redisClient, albumId) {
  const keys = await redisClient.keys(`album_images:${albumId}:*`);
  if (keys.length) await redisClient.del(...keys);
}

async function invalidateByPattern(redisClient, pattern) {
  const keys = await redisClient.keys(pattern);
  if (keys.length) {
    const results = await Promise.all(
      keys.map(async k => {
        const deleted = await redisClient.del(k);
        return { key: k, deleted };
      })
    );
    results.forEach(({ key, deleted }) => {
      if (deleted) {
        console.log(`Deleted key: ${key}`);
      } else {
        console.log(`Key not found (not deleted): ${key}`);
      }
    });
  } else {
    console.log(`No keys found for pattern "${pattern}"`);
  }
}



async function invalidateAllUserAlbumCaches(redisClient, albumId) {
  try {
    const { rows } = await pool.query(
      `SELECT DISTINCT user_id
         FROM shared_album
        WHERE album_id = $1`,
      [albumId]
    );

    console.log("rows",rows)

    for (const { user_id: userId } of rows) {
      await invalidateByPattern(redisClient, `user_albums:${userId}:*`);
      await invalidateByPattern(redisClient, `user_shared_albums:${userId}:*`);
    }

    console.log(
      `Invalidated album caches for albumId ${albumId} (users: ${rows.map(r => r.user_id)})`
    );
  } catch (err) {
    console.error(`Error invalidating album caches for albumId ${albumId}:`, err);
  }
}


async function invalidateUserNotificationCache(redisClient, user_id) {
  const pattern = `notifications:${user_id}:*`;
  const keys = await redisClient.keys(pattern);
  if (keys.length) {
    await redisClient.del(...keys);
    console.log(`Invalidated notification cache for user ${user_id}`);
  }
}


module.exports = {
  invalidateAlbumImageCaches,
  invalidateBlurCache,
  invalidateDuplicateCache,
  invalidateAlbumImagesCache,
  invalidateByPattern,
  invalidateAllUserAlbumCaches,
  invalidateUserNotificationCache
}