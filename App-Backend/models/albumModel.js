const { pool } = require('../models/db');

async function createAlbum({ userId, albumTitle, coverImageUrl }) {
  const query = `
    INSERT INTO albums (user_id, album_title, cover_image_url)
    VALUES ($1, $2, $3)
    RETURNING *
  `;
  const values = [userId, albumTitle, coverImageUrl];
  const result = await pool.query(query, values);
  return result.rows[0];
}

async function getAlbumsByUser(userId, offset = 0, limit = 10) {
  const query = `
    SELECT DISTINCT a.*
    FROM albums a
    LEFT JOIN shared_album sa
      ON sa.album_id = a.id
    WHERE a.user_id = $1
       OR sa.user_id = $1
    ORDER BY a.created_at DESC
    OFFSET $2
    LIMIT $3
  `;
  const result = await pool.query(query, [userId, offset, limit]);

  console.log("rows", result.rows.length);
  return result.rows;
}

async function getAlbumsCountByUser(userId) {
  const query = `
    SELECT
      COUNT(DISTINCT a.id) AS count
    FROM albums a
    LEFT JOIN shared_album sa
      ON sa.album_id = a.id
    WHERE a.user_id = $1
       OR sa.user_id = $1
  `;
  const result = await pool.query(query, [userId]);
  return parseInt(result.rows[0].count, 10);
}


async function getSharedAlbumsByUser(userId, limit = 10, offset = 0) {
  const query = `
    SELECT a.* 
    FROM albums a
    INNER JOIN shared_album sa 
      ON a.id = sa.album_id
    WHERE sa.user_id = $1
      AND a.user_id <> $1        -- exclude albums owned by this user
    ORDER BY a.created_at DESC
    OFFSET $2
    LIMIT $3
  `;
  const result = await pool.query(query, [userId, offset, limit]);
  return result.rows;
}


async function getSharedAlbumsCountByUser(userId) {
  const query = `
    SELECT COUNT(*) 
    FROM albums a
    INNER JOIN shared_album sa 
      ON a.id = sa.album_id
    WHERE sa.user_id = $1
      AND a.user_id <> $1   -- exclude albums owned by this user
  `;
  const result = await pool.query(query, [userId]);
  return parseInt(result.rows[0].count, 10);
}


async function updateAlbum({ albumId, albumTitle, coverImageUrl }) {
  const query = `
    UPDATE albums
    SET album_title = COALESCE($1, album_title),
        cover_image_url = COALESCE($2, cover_image_url),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = $3
    RETURNING *
  `;
  const values = [albumTitle, coverImageUrl, albumId];
  const result = await pool.query(query, values);
  return result.rows[0];
}

async function deleteAlbum(albumId) {
  const query = 'DELETE FROM albums WHERE id = $1 RETURNING *';
  const result = await pool.query(query, [albumId]);
  return result.rows[0];
}

const getAlbumDetails = async (albumId) => {
  const result = await pool.query(
    `SELECT * FROM albums WHERE id = $1`,
    [albumId]
  );
  return result.rows[0];
};



module.exports = {
  createAlbum,
  getAlbumsByUser,
  updateAlbum,
  deleteAlbum,
  getAlbumDetails,
  getSharedAlbumsByUser,
  getAlbumsCountByUser,
  getSharedAlbumsCountByUser
};
