const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const axios = require("axios");
const FormData = require("form-data");
const fs = require("fs");
require('dotenv').config();


const JWT_SECRET = process.env.JWT_SECRET ;
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID 
const client = new OAuth2Client(GOOGLE_CLIENT_ID);

function generateJWT(user) {
  const payload = {
    id: user.id,
    email: user.email,
    displayName: user.display_name,
  };
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '24h' });
}

async function verifyGoogleToken(idToken) {
  const ticket = await client.verifyIdToken({
    idToken,
    audience: GOOGLE_CLIENT_ID,
  });
  const payload = ticket.getPayload();
  return payload;
}

function generateVerificationCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function generateResetToken() {
  return crypto.randomBytes(3).toString('hex').toUpperCase();
}

async function sendEmail({ to, subject, text, html }) {
  const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 587,
    secure: false,
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });

  const mailOptions = {
    from: process.env.EMAIL_USER,
    to,
    subject,
    text,
    html,
  };

  await transporter.sendMail(mailOptions);
}

async function sendVerificationEmail(email, verificationCode) {
  const subject = 'Your Verification Code';
  const text = `Your verification code is: ${verificationCode}`;
  const html = `<p>Your verification code is: <strong>${verificationCode}</strong></p>`;
  return sendEmail({ to: email, subject, text, html });
}

async function sendResetPasswordEmail(email, resetToken) {
  const clientUrl = process.env.CLIENT_URL || 'http://localhost:3000';
  const resetLink = `${clientUrl}/auth/reset-password?token=${resetToken}&email=${encodeURIComponent(email)}`;
  const subject = 'Password Reset Request';
  const text = `You requested to reset your password. Click the following link: ${resetLink}`;
  const html = `<p>You requested to reset your password. Click the following link: <a href="${resetLink}">${resetLink}</a></p>`;
  return sendEmail({ to: email, subject, text, html });
}

async function verifyFace(file) {
  if (!file) return null;
  
  let fileBuffer;
  if (file.buffer) {
    fileBuffer = file.buffer;
  } else if (file.path) {
    fileBuffer = fs.readFileSync(file.path);
  } else {
    throw new Error("No file buffer or file path available");
  }
  
  const formData = new FormData();
  formData.append("file", fileBuffer, { 
    filename: file.originalname || "uploaded_image.jpg",
    contentType: file.mimetype || "application/octet-stream"
  });
  
  const response = await axios.post(FLASK_API, formData, {
    headers: { ...formData.getHeaders() },
  });
  return response.data;
}

module.exports = {
  generateJWT,
  verifyGoogleToken,
  generateVerificationCode,
  generateResetToken,
  sendVerificationEmail,
  sendResetPasswordEmail,
  verifyFace,
};
