# 🎓 Final Year Project – Automated Shared Album

This is the official repository of our **Final Year Project** – a **smart AI-powered mobile app** for automatic photo sharing, duplicate & blur filtering, face recognition, highlights generation, and collaborative album management.

It solves the common problem of **manual photo sharing after group events** by automatically detecting people in photos and sharing them into their personal albums – all while keeping your gallery clean and organized.

---

## 🚀 Features

### 👥 1. Smart Face Recognition & Auto-Sharing
- Uses **MTCNN** for face detection and **FaceNet** for embeddings.
- Automatically detects registered users in uploaded photos.
- Shares photos to albums of users appearing in the image.
- Ensures privacy by skipping unregistered users.

### 🧠 2. Blur & Duplicate Image Detection
- **Laplacian method** for detecting blurry images.
- **Perceptual Hashing (pHash)** and **Hamming Distance** for duplicate detection.
- Blurry/duplicate images go into a separate admin review panel.

### 📁 3. Shared Album Management
- Album creation with `Owner|Admin` and `Viewer` roles.
- Invite participants with Firebase push notifications.
- Real-time role update and access control.
- Album collaboration with multiple users.

### 📷 4. Image Upload & Management
- Upload up to 20 images at once.
- Images stored in **AWS S3**: `album_id/user_id/filename`
- Actions supported:
  - View images (all/shared/flagged)
  - Delete (single/multiple)
  - Unflag blurry/duplicate images
  - Update album cover image

### 🔔 5. Notifications System
- Real-time notifications using **Firebase Cloud Messaging (FCM)**.
- Notifications persisted in **PostgreSQL** for viewing history.
- Infinite scroll, auto-sync background updates.

### 🧵 6. Backend Optimizations (AWS Lambda)
- **Docker-based Lambda** for scalable image processing.
- Key optimizations:
  - DB connection pooling
  - LRU cache for face embeddings
  - ThreadPool for concurrency
  - Blur detection threshold from `ENV`
  - FAISS indexing for fast similarity search

### 🖼️ 7. Highlights Generation (AI-powered)
- One photo picked per album using random logic.
- Captions generated using **Gemini AI API**.
- Images compiled into a **downloadable video using FFmpeg**.

### 🧪 8. Face Recognition Experiments
- Multiple thresholds tested (e.g., 0.5–0.7).
- Model fine-tuned using quality image samples.

### 🔐 9. Authentication & Authorization
- Google OAuth and email/password support.
- Email verification and JWT-based sessions.
- Role-based access for APIs and screens.
- Session expiration detection via Flutter Provider.

### 📱 10. Flutter Mobile App
- Built in **Flutter** with clean & modular UI.
- State management using Provider.
- Custom widgets (`InputField`, `GoogleButton`, `FlushbarHelper`, etc.)
- Responsive layout for different screen sizes.
- Image/video picker, success alerts, and offline handling.

---

## 🛠️ Tech Stack

| Layer       | Technology Used         |
|-------------|--------------------------|
| Frontend    | Flutter (Dart)          |
| Backend     | Node.js (Express)       |
| AI / ML     | MTCNN, FaceNet, OpenCV  |
| Search      | FAISS                   |
| Storage     | AWS S3                  |
| Serverless  | AWS Lambda (Docker)     |
| Database    | PostgreSQL (AWS RDS)    |
| Messaging   | Firebase FCM            |
| Queue       | Bull with Redis         |
| DevOps      | Docker, EC2             |
| Security    | JWT, Email Verification |

---

## 📊 Project Status

✔ Capstone-I: Architecture, Design, Research  
✔ Capstone-II: Full Implementation, Optimizations, and Live Demo Ready  
📆 Final Defense Presentation – **31 July 2025**

---


## 📂 Folder Structure (Sample)

```bash
/
├── backend/
│   ├── controllers/
│   ├── models/
│   ├── routes/
│   ├── services/
│   └── lambda/ (excluded from GitHub)
├── frontend/
│   ├── lib/
│   │   ├── screens/
│   │   ├── widgets/
│   │   ├── providers/
│   │   └── services/
├── README.md
```

---

## 📚 How to Run

### Backend (Node.js)
```bash
cd backend
npm install
node index.js
```

### Frontend (Flutter)
```bash
cd frontend
flutter pub get
flutter run
```

---

## 🔒 Environment & Lambda Code

This repository **does not include** the AWS Lambda source code or `.env` files for security reasons.

- Lambda functions are deployed using Docker on AWS.
- Sensitive credentials (DB, AWS, FCM keys) are excluded.
