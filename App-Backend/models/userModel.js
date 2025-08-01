const { updateProfileImage } = require('../controllers/authController');
const { pool } = require('./db');

async function findUserByEmail(email) {
  const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  return result.rows[0];
}

async function findUserById(id) {
  const result = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
  return result.rows[0];
}

async function createUserGoogle({ email, displayName, googleId, photoUrl,fcmToken }) {
  const insertQuery = `
    INSERT INTO users (email, display_name, google_id, photo_url, signup_method,email_verified,fcm_token)
    VALUES ($1, $2, $3, $4, $5, $6,$7)
    RETURNING *
  `;
  const values = [email, displayName, googleId, photoUrl, 'google',true,fcmToken];
  const result = await pool.query(insertQuery, values);
  return result.rows[0];
}
async function updateFcmToken(userId, fcmToken) {
  const updateQuery = `
    UPDATE users
    SET fcm_token = $1
    WHERE email = $2
    RETURNING *
  `;
  const result = await pool.query(updateQuery, [fcmToken, userId]);
  return result.rows[0];
}

async function createUserEmail({ email, passwordHash, displayName='', verificationToken,photoUrl,fcmToken,email_verified}) {
  const insertQuery = `
  INSERT INTO users (email, password_hash, display_name, signup_method, email_verified, verification_token, photo_url,fcm_token)
  VALUES ($1, $2, $3, $4, $5, $6, $7,$8)
  RETURNING *
`;
const values = [email, passwordHash, displayName, 'email', email_verified, verificationToken, photoUrl,fcmToken];
const result = await pool.query(insertQuery, values);
return result.rows[0];
}

async function updateUserLastLogin({email,fcmToken}) {
  const updateQuery = `
    UPDATE users
    SET last_login = CURRENT_TIMESTAMP, fcm_token = $2
    WHERE email = $1
    RETURNING *
  `;
  const result = await pool.query(updateQuery, [email, fcmToken]);
  return result.rows[0];
}

async function verifyUserEmail(email) {
  const updateQuery = `
    UPDATE users
    SET email_verified = true
    WHERE email = $1
    RETURNING *
  `;
  const result = await pool.query(updateQuery, [email]);
  return result.rows[0];
}

async function updateResetToken(email, token) {
  const updateQuery = `
    UPDATE users
    SET reset_token = $1
    WHERE email = $2
    RETURNING *
  `;
  const result = await pool.query(updateQuery, [token, email]);
  return result.rows[0];
}

async function findUserByEmailAndResetToken(email, token) {
  const query = `
    SELECT * FROM users
    WHERE email = $1 AND reset_token = $2
  `;
  const result = await pool.query(query, [email, token]);
  return result.rows[0];
}

async function updateUserPassword(userId, newPasswordHash) {
  const updateQuery = `
    UPDATE users
    SET password_hash = $1, reset_token = NULL
    WHERE id = $2
    RETURNING *
  `;
  const result = await pool.query(updateQuery, [newPasswordHash, userId]);
  return result.rows[0];
}

async function updateUserVerificationToken(email, newVerificationToken) {
  const updateQuery = `
    UPDATE users
    SET verification_token = $1
    WHERE email = $2
    RETURNING *
  `;
  const result = await pool.query(updateQuery, [newVerificationToken, email]);
  return result.rows[0];
}


async function updateUserProfile({ email, displayName, passwordHash }) {
  if (passwordHash) {
    const query = `
      UPDATE users
      SET display_name = $1,
      password_hash = $2
      WHERE email = $3
      RETURNING *
    `;
    const result = await pool.query(query, [displayName, passwordHash, email]);
    return result.rows[0];
  } else {
    const query = `
      UPDATE users
      SET display_name = $1
      WHERE email = $2
      RETURNING *
    `;
    const result = await pool.query(query, [displayName,email]);
    return result.rows[0];
  }

}

const getUsersByIds = async (userIds) => {
  const result = await pool.query(
    'SELECT id, fcm_token FROM users WHERE id = ANY($1::INTEGER[])',
    [userIds]
  );
  return result.rows;
};

async function updateUserPhotoUrl(userId, photoUrl) {
  const updateQuery = `
    UPDATE users
    SET photo_url = $1,
        image_updated = CURRENT_TIMESTAMP
    WHERE id = $2
    RETURNING *
  `;
  const result = await pool.query(updateQuery, [photoUrl, userId]);
  return result.rows[0];
}

async function getUserAccessRole(albumId, userId) {
  const { rows } = await pool.query(
    `SELECT access_role FROM shared_album WHERE album_id = $1 AND user_id = $2`,
    [albumId, userId]
  );

  if (rows.length === 0) return null;
  return rows[0].access_role; // should return 'admin' or 'viewer'
}

module.exports = {
  findUserByEmail,
  createUserGoogle,
  createUserEmail,
  updateUserLastLogin,
  verifyUserEmail,
  updateResetToken,
  findUserByEmailAndResetToken,
  updateUserPassword,
  updateUserVerificationToken,
  updateUserProfile,
  getUsersByIds,
  findUserById,
  updateFcmToken,
  updateUserPhotoUrl,
  getUserAccessRole
};
