const { pool } = require("../models/db");

async function createImage({ albumId, userId, fileName, s3Url }) {
  const query = `
    INSERT INTO images (album_id, user_id, file_name, s3_url)
    VALUES ($1, $2, $3, $4)
    RETURNING *
  `;
  const values = [albumId, userId, fileName, s3Url];
  const result = await pool.query(query, values);
  return result.rows[0];
}

async function getDuplicateImagesByAlbum(
  albumId,
  duplicate,
  skip = 0,
  limit = 10
) {
  let intAlbumId = parseInt(albumId, 10);
  const query = `
    SELECT * FROM images
    WHERE album_id = $1 AND duplicate=$2
    ORDER BY uploaded_at DESC
    OFFSET $3
    LIMIT $4
  `;
  const result = await pool.query(query, [intAlbumId, duplicate, skip, limit]);
  return result.rows;
}

async function getBlurImagesByAlbum(albumId, status, skip = 0, limit = 10) {
  let intAlbumId = parseInt(albumId, 10);
  const query = `
    SELECT * FROM images
    WHERE album_id = $1 AND status=$2
    ORDER BY uploaded_at DESC
    OFFSET $3
    LIMIT $4
  `;
  const result = await pool.query(query, [intAlbumId, status, skip, limit]);
  return result.rows;
}

async function getImagesByAlbum(
  albumId,
  duplicate,
  status,
  skip = 0,
  limit = 10
) {
  let intAlbumId = parseInt(albumId, 10);
  const query = `
    SELECT * FROM images
    WHERE album_id = $1 AND duplicate=$2 AND status=$3
    ORDER BY uploaded_at DESC
    OFFSET $4
    LIMIT $5
  `;
  const result = await pool.query(query, [
    intAlbumId,
    duplicate,
    status,
    skip,
    limit,
  ]);
  return result.rows;
}

async function getImageById(imageId) {
  const intId = parseInt(imageId, 10);
  const query = `
    SELECT *
    FROM images
    WHERE id = $1
  `;
  const { rows } = await pool.query(query, [intId]);
  if (rows.length === 0) {
    return null; 
  }
  return rows[0];
}

async function deleteImageById(imageId) {
  const intId = parseInt(imageId, 10);
  const query = `
    DELETE FROM images
    WHERE id = $1
    RETURNING *
  `;
  const { rows } = await pool.query(query, [intId]);
  return rows[0] || null;
}

async function getImagesByIds(imageIds) {
  if (!Array.isArray(imageIds) || imageIds.length === 0) {
    return [];
  }

  const validIds = imageIds
    .map(id => {
      const parsed = parseInt(id, 10);
      return isNaN(parsed) ? null : parsed;
    })
    .filter(id => id !== null);

  if (validIds.length === 0) {
    return [];
  }

  const query = `
    SELECT * FROM images
    WHERE id = ANY($1::int[])
  `;
  
  const { rows } = await pool.query(query, [validIds]);
  return rows;
}

async function deleteImagesByIds(imageIds) {
  if (!Array.isArray(imageIds) || imageIds.length === 0) {
    return [];
  }

  const validIds = imageIds
    .map(id => {
      const parsed = parseInt(id, 10);
      return isNaN(parsed) ? null : parsed;
    })
    .filter(id => id !== null);

  if (validIds.length === 0) {
    return [];
  }

  const query = `
    DELETE FROM images
    WHERE id = ANY($1::int[])
    RETURNING *
  `;

  const { rows } = await pool.query(query, [validIds]);
  return rows;
}

async function updateImageToUnflagBlur(imageId) {
  const intId = parseInt(imageId, 10);
  const query = `
    UPDATE images
    SET status = 'clear'
    WHERE id = $1
    RETURNING *
  `;
  const { rows } = await pool.query(query, [intId]);
  return rows[0] || null;
}

async function updateImageToUnflagDuplicate(imageId) {
  const intId = parseInt(imageId, 10);
  const query = `
    UPDATE images
    SET duplicate = false AND duplicate_of_id=null
    WHERE id = $1
    RETURNING *
  `;
  const { rows } = await pool.query(query, [intId]);
  return rows[0] || null;
}

async function unflagBlurImagesByIds(imageIds) {
  const query = `
    UPDATE images
    SET status = 'clear'
    WHERE id = ANY($1::int[])
    RETURNING *;
  `;
  const { rows } = await pool.query(query, [imageIds]);
  return rows;
}

async function unflagDuplicateImagesByIds(imageIds) {
  const query = `
    UPDATE images
    SET duplicate = false AND duplicate_of_id=null
    WHERE id = ANY($1::int[])
    RETURNING *;
  `;
  const { rows } = await pool.query(query, [imageIds]);
  return rows;
}





module.exports = {
  createImage,
  getImagesByAlbum,
  getImageById,
  deleteImageById,
  getDuplicateImagesByAlbum,
  getBlurImagesByAlbum,
  getImagesByIds,
  deleteImagesByIds,
  updateImageToUnflagBlur,
  updateImageToUnflagDuplicate,
  unflagBlurImagesByIds,
  unflagDuplicateImagesByIds,
};
