const { pool } = require("../models/db");


const getAlbumIdsByUserId = async (userId, limit, offset) => {
  const query = `
    SELECT DISTINCT album_id
    FROM shared_album
    WHERE user_id = $1
    ORDER BY album_id
    LIMIT $2 OFFSET $3
  `;
  
  const result = await pool.query(query, [userId, limit, offset]);
  return result.rows.map(row => row.album_id);
};


const getTotalAlbumCountByUserId = async (userId) => {
  const query = `
    SELECT COUNT(DISTINCT album_id) as total_albums
    FROM shared_album
    WHERE user_id = $1
  `;
  
  const result = await pool.query(query, [userId]);
  return parseInt(result.rows[0].total_albums);
};

const getImagesByAlbumIds = async (albumIds) => {
  const query = `
    WITH album_images AS (
      SELECT
        i.album_id,
        i.s3_url,
        i.id as image_id,
        ROW_NUMBER() OVER (PARTITION BY i.album_id ORDER BY RANDOM()) AS rn
      FROM images i
      WHERE i.album_id = ANY($1)
        AND i.status = 'clear'
        AND i.duplicate = false
    ),
    selected_images AS (
      SELECT album_id, s3_url, image_id
      FROM album_images
      WHERE rn <= 3
    )
    SELECT 
      si.album_id,
      si.s3_url,
      JSON_AGG(
        DISTINCT jsonb_build_object(
          'id', u.id,
          'display_name', u.display_name
        )
      ) FILTER (WHERE u.id IS NOT NULL) AS recognized_users
    FROM selected_images si
    LEFT JOIN face_recognition_results frr ON frr.image_id = si.image_id
    LEFT JOIN users u ON u.id = frr.user_id
    GROUP BY si.album_id, si.s3_url
    ORDER BY si.album_id;
  `;
  
  const result = await pool.query(query, [albumIds]);
  return result.rows;
};

module.exports = {
  getAlbumIdsByUserId,
  getTotalAlbumCountByUserId,
  getImagesByAlbumIds
};