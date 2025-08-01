const dotenv = require("dotenv");
dotenv.config();
const axios = require("axios");
const bcrypt = require("bcrypt");
const userModel = require("../models/userModel");
const authService = require("../services/authService");


const {
  invokeSingleFaceRegistration,
} = require("../services/s3Service");
const redisClient = require('../utils/redis.js');
const { getUserStorageStats } = require("../services/storageStatService.js");

const SALT_ROUNDS = 10;

exports.googleSignup = async (req, res) => {
  try {
    const { idToken, email, username,fcmToken } = req.body;
    if (!idToken || !email) {
      return res.status(400).json({ error: "idToken and email are required." });
    }
    const payload = await authService.verifyGoogleToken(idToken);
    if (!payload) {
      return res.status(400).json({ error: "Invalid ID token." });
    }
    if (!payload.email_verified) {
      return res.status(400).json({ error: "Email not verified by Google." });
    }
    const existingUser = await userModel.findUserByEmail(email);
    if (existingUser) {
      return res.status(400).json({ error: "User already exists." });
    }
    const newUser = await userModel.createUserGoogle({
      email,
      displayName: username || payload.name,
      googleId: payload.sub,
      photoUrl: "",
      email_verified: payload.email_verified,
      fcmToken,
    });

    const token = authService.generateJWT(newUser);

    return res.status(201).json({
      token,
      user: {
        email: newUser.email,
        username: newUser.display_name,
        profileImageUrl: newUser.photo_url,
        isVerified: newUser.email_verified,
      },
    });
  } catch (error) {
    console.error("Error in googleSignup:", error);
    return res.status(500).json({ error: "Signup failed" });
  }
};

exports.googleLogin = async (req, res) => {
  try {
    const { idToken, email,fcmToken } = req.body;
    if (!idToken || !email) {
      return res.status(400).json({ error: "idToken and email are required." });
    }
    const payload = await authService.verifyGoogleToken(idToken);
    if (!payload) {
      return res.status(400).json({ error: "Invalid ID token." });
    }
    if (!payload.email_verified) {
      return res.status(400).json({ error: "Email not verified by Google." });
    }
    const user = await userModel.findUserByEmail(email);
    if (!user) {
      return res
        .status(400)
        .json({ error: "User does not exist. Please sign up first." });
    }
    const updatedUser = await userModel.updateUserLastLogin({
      email,
      fcmToken,
    });
    const token = authService.generateJWT(updatedUser);
    console.log(updatedUser.photo_url)
    return res.status(200).json({
      token,
      user: {
        email: updatedUser.email,
        username: updatedUser.display_name,
        profileImageUrl: updatedUser.photo_url,
        isVerified: updatedUser.email_verified,
        imageUpdated: updatedUser.image_updated, 
      },
    });
  } catch (error) {
    console.error("Error in googleLogin:", error);
    return res.status(500).json({ error: "Login failed" });
  }
};


exports.emailSignup = async (req, res) => {
  try {
    const { email, password, username, fcmToken } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: "Email and password are required." });
    }

    const existingUser = await userModel.findUserByEmail(email);
    if (existingUser) {
      return res.status(400).json({ error: "User already exists." });
    }

    const verificationCode = authService.generateVerificationCode();
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    const tempUserData = JSON.stringify({
      email,
      passwordHash,
      username: username || '',
      verificationCode,
      fcmToken,
    });
    await redisClient.setEx(`signup:${email}`, 300, tempUserData);

    // Send verification email
    await authService.sendVerificationEmail(email, verificationCode);

    return res.status(201).json({
      message: "Signup initiated. Verification code sent to email.",
    });
  } catch (error) {
    console.error("Error in emailSignup:", error);
    return res.status(500).json({ error: "Signup failed" });
  }
};




exports.verifyEmail = async (req, res) => {
  try {
    const { email, verificationCode } = req.body;

    if (!email || !verificationCode) {
      return res.status(400).json({ error: "Email and verification code are required." });
    }

    const tempUserDataStr = await redisClient.get(`signup:${email}`);

    if (!tempUserDataStr) {
      return res.status(400).json({ error: "Verification code expired or signup not found." });
    }

    const tempUserData = JSON.parse(tempUserDataStr);

    if (verificationCode !== tempUserData.verificationCode) {
      return res.status(400).json({ error: "Invalid verification code." });
    }

    const newUser = await userModel.createUserEmail({
      email: tempUserData.email,
      passwordHash: tempUserData.passwordHash,
      displayName: tempUserData.username,
      verificationToken: null,
      photoUrl: "",
      fcmToken: tempUserData.fcmToken,
      email_verified: true,
    });

    await redisClient.del(`signup:${email}`);

    const token = authService.generateJWT(newUser);

    return res.status(200).json({
      token,
      user: {
        email: newUser.email,
        username: newUser.display_name,
        profileImageUrl: newUser.photo_url,
        isVerified: newUser.email_verified,
      },
      message: "Email verified successfully and signup completed.",
    });
  } catch (error) {
    console.error("Error in verifyEmail:", error);
    return res.status(500).json({ error: "Verification failed" });
  }
};


exports.emailLogin = async (req, res) => {
  try {
    const { email, password,fcmToken } = req.body;
    if (!email || !password) {
      return res
        .status(400)
        .json({ error: "Email and password are required." });
    }
    const user = await userModel.findUserByEmail(email);
                
    if (!user) {
      return res.status(400).json({ error: "User does not exist." });
    }
     const updatedUser=await userModel.updateFcmToken(email, fcmToken);
    const passwordMatch = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatch) {
      return res.status(400).json({ error: "Invalid password." });
    }
    const token = authService.generateJWT(user);
    return res.status(200).json({
      token,
      user: {
        email: updatedUser.email,
        username: updatedUser.display_name,
        profileImageUrl: updatedUser.photo_url,
        isVerified: updatedUser.email_verified,
        imageUpdated: updatedUser.image_updated, 
      },
    });
  } catch (error) {
    console.error("Error in emailLogin:", error);
    return res.status(500).json({ error: "Login failed" });
  }
};

exports.forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: "Email is required." });
    }
    const user = await userModel.findUserByEmail(email);
    if (!user) {
      return res.status(400).json({ error: "User does not exist." });
    }
    const resetToken = authService.generateResetToken();
    await userModel.updateResetToken(email, resetToken);
    await authService.sendResetPasswordEmail(email, resetToken);
    return res
      .status(200)
      .json({ message: "Password reset link sent to your email." });
  } catch (error) {
    console.error("Error in forgotPassword:", error);
    return res
      .status(500)
      .json({ error: "Failed to send password reset link." });
  }
};

exports.resetPassword = async (req, res) => {
  try {
    const { token, email, newPassword } = req.body;
    if (!token || !email || !newPassword) {
      return res
        .status(400)
        .json({ error: "Token, email, and new password are required." });
    }
    const user = await userModel.findUserByEmailAndResetToken(email, token);
    if (!user) {
      return res.status(400).json({ error: "Invalid token or email." });
    }
    const newPasswordHash = await bcrypt.hash(newPassword, SALT_ROUNDS);
    await userModel.updateUserPassword(user.id, newPasswordHash);
    return res.status(200).json({ message: "Password successfully reset." });
  } catch (error) {
    console.error("Error in resetPassword:", error);
    return res.status(500).json({ error: "Reset password failed." });
  }
};

exports.getResetPasswordPage = (req, res) => {
  const path = require("path");
  res.sendFile(path.join(__dirname, "../public", "reset-password.html"));
};


exports.resendVerificationCode = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: "Email is required." });
    }

    const tempUserDataJson = await redisClient.get(`signup:${email}`);
    if (!tempUserDataJson) {
      return res.status(404).json({ error: "No pending verification found for this email." });
    }

    const tempUserData = JSON.parse(tempUserDataJson);

    const newVerificationCode = authService.generateVerificationCode();
    tempUserData.verificationCode = newVerificationCode;

    await redisClient.setEx(`signup:${email}`, 300, JSON.stringify(tempUserData));

    await authService.sendVerificationEmail(email, newVerificationCode);

    return res.status(200).json({
      message: "Verification code resent successfully.",
    });
  } catch (error) {
    console.error("Error in resendVerificationCode:", error);
    return res
      .status(500)
      .json({ error: "Failed to resend verification code." });
  }
};


exports.updateProfile = async (req, res) => {
  try {
    const { email, username, password } = req.body;

    if (req.user.email !== email) {
      return res
        .status(403)
        .json({ error: "Forbidden: You can only update your own profile." });
    }
   
    let passwordHash = null;
    if (password && password.trim() !== "") {
      passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    }


    const updatedUser = await userModel.updateUserProfile({
      email,
      displayName: username,
      passwordHash,
    });

    console.log("Updated user: ", updatedUser);

    return res.status(200).json({
      user: {
        email: updatedUser.email,
        username: updatedUser.display_name,
        profileImageUrl: updatedUser.photo_url,
        isVerified: updatedUser.email_verified,
        imageUpdated: updatedUser.image_updated,
      },
      message: "Profile updated successfully",
    });
  } catch (error) {
    console.error("Error in updateProfile:", error);
    return res.status(500).json({ error: "Profile update failed" });
  }
};



exports.updateProfileImage = async (req, res) => {
  const { frontImageUrl, leftImageUrl, rightImageUrl } = req.body;
  console.log("Received Image URLs:", req.body);

  try {
    if (!frontImageUrl || !leftImageUrl || !rightImageUrl) {
      return res.status(400).json({ error: "All image URLs (front, left, right) are required." });
    }

    const urls = [
      stripS3Prefix(frontImageUrl),
      stripS3Prefix(leftImageUrl),
      stripS3Prefix(rightImageUrl),
    ];

    console.log("Stripped URLs:", urls);

    // Building array payload for Lambda (same as your PowerShell example)
    const eventPayload = urls.map((key) => ({
      s3: {
        bucket: { name: process.env.AWS_BUCKET_NAME },
        object: { key },
      },
    }));

    console.log("Payload for Lambda:", JSON.stringify(eventPayload, null, 2));

    const result = await invokeSingleFaceRegistration(eventPayload);

    console.log("Result from invokeTripleSideFaceRegistration:", result);

    if (result[0].error) {
      return res.status(400).json({ error: result[0].error, details: result });
    }

    const user = await userModel.findUserById(req.user.id);
    if (!user) {
      return res.status(404).json({ error: "User not found." });
    }
    
    const updatedUser=await userModel.updateUserPhotoUrl(req.user.id,frontImageUrl);
    const token = authService.generateJWT(user);

    res.status(200).json({
      message: result.message,
      user: {
        email: updatedUser.email,
        username: updatedUser.display_name,
        profileImageUrl: updatedUser.photo_url,
        isVerified: updatedUser.email_verified,
        imageUpdated: updatedUser.image_updated, 
      },
      token,
    });
  } catch (error) {
    console.error("Error in updateProfileImage:", error);
    return res.status(500).json({ error: "Profile image update failed." });
  }
};

function stripS3Prefix(url) {
  const prefix = `https://${process.env.AWS_BUCKET_NAME}.s3.amazonaws.com/`;
  return url.startsWith(prefix) ? url.slice(prefix.length) : url;
}


exports.getUserStorageUsage = async (req, res) => {
  const userId = req.user.id;
  const cacheKey = `user_storage_usage:${userId}`;
  try {
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.status(200).json(JSON.parse(cached));
    }
    const stats = await getUserStorageStats(userId);
    await redisClient.set(cacheKey, JSON.stringify(stats), 'EX', 300);
    console.log(stats);
    return res.status(200).json(stats);
  } catch (error) {
    console.error('Error calculating storage usage:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
};


exports.getUserProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await userModel.findUserById(userId);
    
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }
    
    return res.status(200).json({
      user: {
        email: user.email,
        username: user.display_name,
        profileImageUrl: user.photo_url,
        isVerified: user.email_verified,
        imageUpdated: user.image_updated,
      }
    });
  } catch (error) {
    console.error("Error fetching user profile:", error);
    return res.status(500).json({ error: "Failed to fetch user profile" });
  }
};

