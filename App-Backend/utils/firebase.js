// services/firebase.js
const admin = require('firebase-admin');
const serviceAccount = require('./firebasekey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  // databaseURL: 'https://<your-project-id>.firebaseio.com'
});

module.exports = admin;
