// Assuming you have initialized Firebase admin elsewhere
const admin = require('../utils/firebase'); 

const sendPushNotification = async (fcmToken, title, body, data = {}) => {
  if (!fcmToken) return null;
  const message = {
    notification: { title, body },
    data,
    android: {
      priority: 'high',
    },
    token: fcmToken
  };
  console.log('Sending FCM message:', JSON.stringify(message, null, 2));
  try {
    return await admin.messaging().send(message);
  } catch (error) {
    console.error('Error sending push notification:', error);
    return null;
  }
};

module.exports = { sendPushNotification };
