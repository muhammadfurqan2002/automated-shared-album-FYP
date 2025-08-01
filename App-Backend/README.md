# App-Backend

## Overview

This project is a Node.js backend application built with Express. It provides APIs for album management, user authentication, image handling, and highlights. The backend is structured for clarity and maintainability, making it suitable for academic and production use.

## Features

- User authentication (login, registration, password reset)
- Album and highlight management
- Image upload and processing
- Caching and batch operations
- RESTful API endpoints

## Directory Structure

```
App-Backend/
├── controllers/         # Express route controllers (album, auth, image, etc.)
├── middlewares/         # Express middleware (e.g., authentication)
├── models/              # Database models (albums, highlights, etc.)
├── public/              # Public assets (HTML, uploads)
├── routes/              # Express route definitions
├── services/            # Business logic and service layer
├── utils/               # Utility modules (cache, firebase, etc.)
├── index.js             # Express app entry point
├── package.json         # Node.js dependencies and scripts
├── package-lock.json    # Node.js lockfile
└── README.md            # Project documentation
```

## Prerequisites

- Node.js (v14+ recommended)
- npm (Node Package Manager)

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd App-Backend
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Start the Node.js Server

```bash
node index.js
```

## Usage

- The Node.js server runs the main API (default: `http://localhost:3000`)
- API endpoints are available for albums, authentication, highlights, and images.

## API Endpoints and Methods

Below is a detailed explanation of each route and method provided by the backend. Each route is defined in the `routes/` directory and handled by corresponding controllers in the `controllers/` directory.

### Authentication Routes (`/auth`)

- **POST `/auth/register`**
  - Registers a new user.
  - **Body:** `{ username, email, password }`
  - **Response:** Success message or error.

- **POST `/auth/login`**
  - Authenticates a user and returns a token.
  - **Body:** `{ email, password }`
  - **Response:** JWT token and user info.

- **POST `/auth/reset-password`**
  - Initiates password reset process.
  - **Body:** `{ email }`
  - **Response:** Email sent confirmation or error.

- **POST `/auth/update-password`**
  - Updates the user's password.
  - **Body:** `{ token, newPassword }`
  - **Response:** Success message or error.

### Album Routes (`/albums`)

- **GET `/albums`**
  - Retrieves a list of all albums.
  - **Response:** Array of album objects.

- **GET `/albums/:id`**
  - Retrieves details of a specific album by ID.
  - **Response:** Album object or error if not found.

- **POST `/albums`**
  - Creates a new album.
  - **Body:** `{ title, description, ... }`
  - **Response:** Created album object.

- **PUT `/albums/:id`**
  - Updates an existing album by ID.
  - **Body:** Fields to update.
  - **Response:** Updated album object or error.

- **DELETE `/albums/:id`**
  - Deletes an album by ID.
  - **Response:** Success message or error.

### Highlight Routes (`/highlights`)

- **GET `/highlights`**
  - Retrieves all highlights.
  - **Response:** Array of highlight objects.

- **POST `/images/upload`**
  - Uploads an image file.
  - **Body:** Multipart/form-data with image file.
  - **Response:** Uploaded image info or error.

- **GET `/images/:filename`**
  - Retrieves an image by filename.
  - **Response:** Image file or error if not found.

### Other Notable Endpoints

- **Batch Operations:**
  - Endpoints for batch processing (see `services/batchService.js`).
- **Caching:**
  - Utilizes caching for performance (see `utils/cache.js`).

## Middleware

- **Authentication Middleware:**
  - Protects routes that require authentication (see `middlewares/authMiddleware.js`).

## Models

- **Album Model:**
  - Defines the schema for albums (see `models/albumModel.js`).
- **Highlight Model:**
  - Defines the schema for highlights (see `models/highlightModel.js`).
- **User Model:**
  - Defines the schema for users (see `models/userModel.js`).

## Services

- **Business Logic:**
  - All core logic is handled in the `services/` directory, separating concerns from controllers.

## Utilities

- **Cache Utility:**
  - Handles caching for improved performance.
- **Firebase Utility:**
  - Integrates with Firebase for notifications or storage (if used).
