const { Pool } = require('pg');
const dotenv = require('dotenv');
dotenv.config();


const pool = new Pool({
  user: process.env.DB_USER ,
  host: process.env.DB_HOST ,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
  ssl: {
    require: false,
    rejectUnauthorized: false
  }
});

const createUsersTable = ` 
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255),           
  display_name VARCHAR(255),
  google_id VARCHAR(255),
  photo_url TEXT,
  registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP,
  signup_method VARCHAR(50),
  email_verified BOOLEAN DEFAULT false,  
  verification_token VARCHAR(255),       
  reset_token VARCHAR(255),
  embedding VECTOR(512)
)`;

const createAlbumsTable = `
CREATE TABLE IF NOT EXISTS albums (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  album_title VARCHAR(255) NOT NULL,
  cover_image_url TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)`;

const createImagesTable = `
CREATE TABLE IF NOT EXISTS images (
  id SERIAL PRIMARY KEY,
  album_id INTEGER NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  file_name VARCHAR(255) NOT NULL,
  s3_url TEXT NOT NULL,
  uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)`;
const createNotificationsTable = `
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  "notificationId" UUID UNIQUE DEFAULT gen_random_uuid(),
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)`;;

const initializeDatabase = async () => {
  try {
    await pool.query('CREATE EXTENSION IF NOT EXISTS vector');
    await pool.query('CREATE EXTENSION IF NOT EXISTS pgcrypto');
    await pool.query(createUsersTable);
    await pool.query(createAlbumsTable);
    await pool.query(createImagesTable);
    await pool.query(createNotificationsTable);
    console.log('Database tables ensured');
  } catch (err) {
    console.error('Database initialization error', err);
  }
};

module.exports = {
  pool,
  initializeDatabase
};