# MediNexa - Universal AI Medical Platform 🩺

MediNexa is a premium, modern digital healthcare application built with **Flutter** (frontend) and **Flask** (backend), featuring a secure and unified storage architecture powered by **MongoDB GridFS** and **Google Gemini AI (Gemini 2.5 Flash)**.

---

## 📖 Table of Contents
1. [Overview & Design Architecture](#-overview--design-architecture)
2. [Key Features](#-key-features)
   - [My Health Documents](#1-my-health-documents)
   - [Laboratory & Medical Reports](#2-laboratory--medical-reports)
   - [Medoc Analyze (AI Document Classifier)](#3-medoc-analyze)
   - [AI Health Chatbot](#4-ai-chatbot)
3. [Security & Access Authorization](#-security--access-authorization)
4. [Technology Stack](#-technology-stack)
5. [Project Directory Mappings](#-project-directory-mappings)
6. [API Documentation](#-api-documentation)
7. [Installation & Setup](#-installation--setup)
   - [Local Configuration](#1-local-configuration)
   - [Production/Render Deployment](#2-productionrender-deployment)

---

## 🎨 Overview & Design Architecture

MediNexa coordinates clinical records, patient documents, and lab reports under a unified data backend. Unlike traditional designs where files are sandboxed on multiple servers, MediNexa uses **MongoDB GridFS** as its singular secure repository.

### System Workflow
```
[ Flutter Mobile App ]
         │
         ▼ (Authorization: Bearer <Firebase ID Token>)
[ Flask Web Server ]
         │
         ├─► [ Firebase Admin SDK ] ──► (Verify Token, Get Role)
         │
         ├─► [ MongoDB GridFS ] ──────► (Blob Upload/Download)
         │
         ├─► [ storage_metadata ] ────► (Filename, Size, MIME, patientId)
         │
         └─► [ Google Gemini AI ] ────► (Structured JSON Extraction)
```

---

## 🚀 Key Features

### 1. My Health Documents
A secure storage and retrieval sandbox that handles patients' files. All files are stored directly inside **MongoDB GridFS**:
*   **Zero-Firestore Patient Sandbox**: All patient records and personal documents are stored in MongoDB GridFS, removing all read/write/listener operations on Firestore subcollections (`users/{uid}/documents` and `users/{uid}/reports`) to prevent security and permission gaps.
*   **Metadata Single Source of Truth**: Document properties such as size, MIME content-type, original filename, upload time, and category name are stored directly in MongoDB's `storage_metadata` collection.
*   **Automatic Category Formatting**: The user interface scans document names for keywords to dynamically categorize and assign premium typography and custom emojis:
    *   🩺 `Previous Prescription`
    *   🖼 `MRI Scan` / `CT Scans`
    *   📄 `Insurance Card` / `ID Cards`
    *   🩸 `Blood Test` / `Lab Reports`

### 2. Laboratory & Medical Reports
A secure laboratory portal and doctor review dashboard where laboratories can upload PDF reports directly for a patient.
*   **Doctor Review Panel**: Doctors can dynamically view actual reports uploaded by laboratories. If no reports exist, a placeholder message appears.
*   **AI Summary Independent**: Standard AI-generated report summaries are separated and kept distinct from the primary "Lab & Medical Reports" storage dashboard.
*   **Lab Name Resolution**: Resolves and displays the uploading laboratory name dynamically by fetching matching user records from Firestore.

### 3. Medoc Analyze
Our universal medical document analyzer automatically classifies and parses 5 different types of medical documents:
*   **Prescription**: Extracts doctor details, patient name, date, diagnosis, and fully structured medicines list.
*   **Laboratory Report**: Extracts abnormal test parameters, reference ranges, and provides Gen-Z Hinglish explanations (e.g., `💡 Khoon ki kami indicate karta hai.`).
*   **Medical Bill**: Extracts billing items, hospital name, and billing summary.
*   **Discharge Summary**: Summarizes treatment history, medications, and follow-ups.
*   **Unknown Document**: Displays a warning card if the document isn't recognized.

### 4. AI Chatbot
Interactive medical chatbot panel utilizing Gemini AI to query symptoms, medicine interactions, and nutritional guidance securely.
*   **Persistent Chat History**: Chat sessions are stored securely in Firestore, allowing users to persist conversations across devices.
*   **Lazy Loading & Optimizations**: Only session metadata is loaded initially. Full message history is lazy-loaded upon opening a specific chat to preserve database reads.
*   **Total Privacy**: Users can permanently hard-delete conversations directly from the database.

### 5. Advanced Authentication & UI Upgrades
*   **Doctor Location & Maps Integration**: Doctors can add their clinic address and Google Maps links. Patients can launch Google Maps directly from the Doctor Cards.
*   **Mandatory Email Verification**: Prevents unverified registrations from polluting the database. Upon signup, users receive a verification link and are auto-signed out. The app verifies `emailVerified` on login, launching a premium glassmorphic verification dialog if verification is incomplete.
*   **Lazy Firestore Creation**: The Firestore user document is created only after the user's email has been verified and they log in for the first time.
*   **Secure Password Reset**: Built-in glassmorphic forgot password panel linked with Firebase `sendPasswordResetEmail()`.
*   **Premium Glassmorphic Theme & Accents**: Vibrant purple accents matched dynamically across light/dark modes with beautiful glowing Custom Paint background circles on dashboard cards.
*   **Responsive Login Layout**: Built with a flexible layout architecture that adapts beautifully to different device sizes and open soft keyboards, preventing vertical screen clipping.
*   **Sleek 3D App Icon**: Installed a premium custom 3D glowing shield launch icon for mobile configurations.

---

## 🛡️ Security & Access Authorization

To protect patient files from unauthorized access:
*   **Token-Based API Verification**: The backend verifies incoming Firebase ID tokens using the `Authorization: Bearer <token>` header.
*   **Secure Patient Endpoint**: Patients retrieve their files via `GET /api/storage/patient` where the system resolves the patient's UID directly from the secure decoded JWT payload, preventing ID spoofing.
*   **Dual Appointment Check for Doctors**: Doctors are allowed to view patient documents and lab reports only if an active or completed appointment exists between them. The backend dynamically verifies this link by checking **MongoDB** first and falling back to **Firestore**'s `appointments` collection, preventing false-negative access blocks.
*   **Admins**: Enjoy full read access for auditing and platform management.

---

## 🛠️ Technology Stack

*   **Frontend**: Flutter (Dart), Google Fonts (Outfit, Inter), Syncfusion PDF Viewer
*   **Backend**: Python, Flask, PyTesseract (OCR Fallback)
*   **AI Engine**: Google Generative AI (Gemini 2.5 Flash)
*   **Database**: MongoDB Atlas (GridFS & Metadata), Firestore (User profiles & appointments)

---

## 📂 Project Directory Mappings

```
MediNexa/
├── backend/                     # Flask Python Server
│   ├── app.py                   # Main backend application
│   ├── firebase_config.py       # Firebase Token & Admin SDK config
│   ├── db.py                    # MongoDB Connection helpers
│   ├── requirements.txt         # Backend Python dependencies
│   ├── config/
│   │   └── mongodb.py           # Indexing & GridFS connections
│   ├── routes/
│   │   ├── __init__.py          # Main routing & appointment endpoints
│   │   └── storage_routes.py    # GridFS Storage API endpoints
│   └── services/
│       └── storage_service.py   # Mongo GridFS CRUD service
├── frontend/                    # Flutter Mobile Application
│   ├── lib/
│   │   ├── main.dart            # Flutter app routing
│   │   ├── config/
│   │   │   └── api_config.dart  # Backend API endpoints URL
│   │   ├── screens/
│   │   │   ├── pdf_viewer_screen.dart   # In-app PDF preview & downloads
│   │   │   ├── image_viewer_screen.dart # Image view panel
│   │   │   ├── patient/
│   │   │   │   └── patient_dashboard.dart # Documents sheet, upload, & delete
│   │   │   └── doctor/
│   │   │       └── patient_details_screen.dart # Patient files review
│   │   └── services/
│   │       └── lab_service.dart # Lab API interface
│   └── pubspec.yaml             # Flutter dependencies
└── README.md                    # Project documentation
```

---

## 🔌 API Documentation

All storage routes require `Authorization: Bearer <ID_TOKEN>` header.

### 1. Upload File
*   **URL**: `/api/storage/upload`
*   **Method**: `POST`
*   **Payload (Multipart)**:
    *   `file`: The PDF/Image file bytes
    *   `patientId`: ID of the patient
    *   `documentName` (optional): Name label
    *   `reportType` (optional): `patient_document` or `lab_report`
*   **Success Response (201)**:
    ```json
    {
      "message": "File uploaded successfully",
      "fileId": "6a3fa71e73761241d3b3..."
    }
    ```

### 2. Get Patient Documents (Self)
*   **URL**: `/api/storage/patient`
*   **Method**: `GET`
*   **Success Response (200)**:
    ```json
    [
      {
        "fileId": "6a3fa71e73761241d3b354ef",
        "documentName": "Blood Test Report",
        "originalFilename": "blood_test.pdf",
        "contentType": "application/pdf",
        "fileSize": "1.2 MB",
        "createdAt": "2026-06-27T10:42:00Z"
      }
    ]
    ```

### 3. Get Patient Documents for Doctor/Admin
*   **URL**: `/api/storage/patient/<patientId>/documents`
*   **Method**: `GET`
*   **Success Response (200)**: Matches format above (requires verified doctor appointment).

### 4. Get Patient Lab Reports for Doctor/Admin
*   **URL**: `/api/storage/patient/<patientId>/lab-reports`
*   **Method**: `GET`
*   **Success Response (200)**: List of lab reports including `labName`.

### 5. Download File
*   **URL**: `/api/storage/file/<fileId>`
*   **Method**: `GET`
*   **Success Response (200)**: Binary Stream of the stored file (with dynamic Content-Type headers).

### 6. Delete File
*   **URL**: `/api/storage/delete/<fileId>`
*   **Method**: `DELETE`
*   **Success Response (200)**:
    ```json
    { "message": "File and metadata deleted successfully" }
    ```

---

## ⚙️ Installation & Setup

### 1. Local Configuration

#### Backend Setup
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a Python virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate   # Windows: venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Create a `.env` file in the `backend/` directory:
   ```env
   PORT=5000
   MONGO_URI=mongodb+srv://<user>:<password>@cluster.mongodb.net/
   DB_NAME=medinexa
   FIREBASE_CREDENTIALS_PATH=medinexa-cf258-firebase-adminsdk-fbsvc-f5ec0d9510.json
   GEMINI_API_KEY=AIzaSy...your_gemini_key
   ```
5. Run the development server:
   ```bash
   python app.py
   ```

#### Frontend Setup
1. Navigate to the frontend directory:
   ```bash
   cd ../frontend
   ```
2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```
3. Configure the correct base URL in `lib/config/api_config.dart`:
   ```dart
   static const String baseUrl = 'http://127.0.0.1:5000/api';
   ```
4. Run the application:
   ```bash
   flutter run
   ```

### 2. Production/Render Deployment
For production hosting on platforms like **Render**:
1. Store your Firebase Admin credentials in `FIREBASE_CREDENTIALS_JSON` as a Base64-encoded string.
2. The code in `firebase_config.py` automatically detects and decodes the Base64 configuration at runtime, removing the need to upload credentials to GitHub.
3. Whitelist `0.0.0.0/0` in your MongoDB Atlas Network Access configuration.
