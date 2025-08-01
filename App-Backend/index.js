
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');

const { initializeDatabase } = require('./models/db');

const authRoutes = require('./routes/authRoutes');
const albumRoutes = require('./routes/albumRoutes');
const imageRoutes = require('./routes/imageRoutes');
const sharedAlbumRoutes = require('./routes/sharedAlbumRoutes');
const highlightRoutes = require('./routes/highlightRoute');
const notificationRoutes = require('./routes/notificationRoutes');

const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

app.use(express.static(path.join(__dirname, 'public')));

// Init database
initializeDatabase();

// Routes
app.use('/auth', authRoutes);
app.use('/albums', albumRoutes);
app.use('/images', imageRoutes);
app.use('/shared', sharedAlbumRoutes);
app.use('/highlight', highlightRoutes);
app.use('/notifications', notificationRoutes);

// Error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal Server Error' });
});

// Start server
const PORT = process.env.PORT;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
