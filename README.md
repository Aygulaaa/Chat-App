# 💬 Teleflow - Modern Real-Time Chat Application

Teleflow is a premium, real-time messaging application designed for seamless communication. It features a cross-platform mobile frontend built with **Flutter** (using Clean Architecture and Riverpod) and a robust, scalable backend powered by **Node.js**, **TypeScript**, **Express**, **Socket.io**, and **PostgreSQL**.

---

## 🚀 Key Features

*   **⚡ Real-Time Messaging:** Socket.io-powered low latency communication with real-time typing indicators, read receipts, and online status.
*   **📁 Multimedia Sharing:** Integrated with Cloudinary and Multer for secure and fast file uploads (Images, Audio, Documents).
*   **👥 Contacts Management:** Effortlessly search for users, add them to your contacts list, or block/unblock unwanted contacts.
*   **⚙️ Rich User Customization:** Interactive settings including theme toggles, privacy settings (hide last seen, hide read receipts), custom bios, and avatars.
*   **🎨 Glassmorphic UI:** A visually stunning dark-mode-first user interface with smooth animations and layout.

---

## 🛠️ Technology Stack

### Backend
| Technology | Purpose |
| :--- | :--- |
| **Node.js & TypeScript** | Runtime environment and strongly-typed codebase |
| **Express** | REST API framework for authentication, contacts, settings, and user management |
| **Socket.io** | WebSocket server for low-latency, real-time event broadcasting |
| **PostgreSQL** | Primary relational database for persistence |
| **Cloudinary & Multer** | Media uploads and cloud storage hosting |
| **JWT & BcryptJS** | Secure token-based authentication and password hashing |

### Frontend
| Technology | Purpose |
| :--- | :--- |
| **Flutter & Dart** | Cross-platform mobile framework (Android, iOS) |
| **Riverpod** | State management and dependency injection |
| **Socket.io Client** | Real-time connection to the backend server |
| **Flutter Secure Storage** | Secure on-device key-value storage for JWT tokens |
| **Supabase Flutter** | Client-side SDK integration |
| **Just Audio & Record** | Voice note recording and media playback |

---

## 📂 Project Architecture

```text
my_chat_app/
├── backend/                  # Node.js TypeScript server
│   ├── src/
│   │   ├── db.ts             # Database connection pool (pg)
│   │   ├── index.ts          # Server entry point, setup Express & Socket.io
│   │   ├── middleware/       # Custom middleware (JWT auth, error handlers)
│   │   └── features/         # Modular backend features
│   │       ├── auth/         # Register, Login, Token validation
│   │       ├── chat/         # Chats, Messages, group management, Socket handlers
│   │       ├── contacts/     # Contact lists, blocking users, user searches
│   │       ├── settings/     # Privacy configurations and user preferences
│   │       └── users/        # Profile updates, avatar uploading, user info
│   └── package.json          # Node dependencies & running scripts
│
└── frontend/                 # Flutter mobile application
    ├── lib/
    │   ├── main.dart         # Flutter app entry point, SDK initializations
    │   ├── core/             # Core features (Networking, Local Storage, Utilities)
    │   └── features/         # Clean Architecture feature modules
    │       ├── app_shell/    # Core layout with glass bottom navigation bar
    │       ├── auth/         # User Authentication UI, controllers, providers
    │       ├── chat/         # Chat rooms, messaging threads, attachment handlers
    │       ├── contacts/     # Contacts view and search bar
    │       ├── settings/     # User options and dark mode triggers
    │       └── users/        # User Profile setup (avatar, bio, birth date)
    └── pubspec.yaml          # Flutter package dependencies
```

---

## 📦 Database Schema Setup

Teleflow uses **PostgreSQL**. You can use a local database instance or cloud-hosted database (like **Supabase**). Execute the following script to create all necessary database tables and relations:

```sql
-- 1. Create Users Table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    avatar TEXT,
    bio TEXT,
    status VARCHAR(20) DEFAULT 'offline',
    last_seen TIMESTAMP DEFAULT NOW(),
    birth_date DATE
);

-- 2. Create User Settings Table
CREATE TABLE IF NOT EXISTS user_settings (
    user_id INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    notifications_enabled BOOLEAN DEFAULT TRUE,
    theme VARCHAR(20) DEFAULT 'dark',
    hide_last_seen BOOLEAN DEFAULT FALSE,
    hide_read_receipts BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 3. Create Contacts Table
CREATE TABLE IF NOT EXISTS contacts (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active' | 'blocked'
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (user_id, contact_user_id)
);

-- 4. Create Chats Table
CREATE TABLE IF NOT EXISTS chats (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150),
    type VARCHAR(20) DEFAULT 'direct', -- 'direct' | 'group'
    avatar TEXT,
    created_by INT REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 5. Create Chat Members Table (Many-to-Many Junction)
CREATE TABLE IF NOT EXISTS chat_members (
    chat_id INT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (chat_id, user_id)
);

-- 6. Create Messages Table
CREATE TABLE IF NOT EXISTS messages (
    id SERIAL PRIMARY KEY,
    chat_id INT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    sender_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text TEXT,
    file_type VARCHAR(50), -- 'image' | 'video' | 'audio' | 'document'
    file_url TEXT,
    original_name VARCHAR(255),
    mime_type VARCHAR(100),
    file_size INT,
    created_at TIMESTAMP DEFAULT NOW(),
    delivered_at TIMESTAMP,
    read_at TIMESTAMP
);

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_chat_members_user_id ON chat_members(user_id);
```

---

## ⚙️ Development Setup & Installation

### 1. Backend Server Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install npm dependencies:
   ```bash
   npm install
   ```
3. Copy environment configuration file and update the values:
   ```bash
   cp .env.example .env
   ```
   Modify `.env` with your PostgreSQL database URI, JWT secret, and Cloudinary credentials:
   ```env
   PORT=5000
   DATABASE_URL=postgresql://<username>:<password>@<host>:<port>/<dbname>
   JWT_SECRET=your_jwt_signing_secret_here
   CLOUDINARY_CLOUD_NAME=your_cloudinary_cloud_name
   CLOUDINARY_API_KEY=your_cloudinary_api_key
   CLOUDINARY_API_SECRET=your_cloudinary_api_secret
   ```
4. Launch the server in development mode:
   ```bash
   npm run dev
   ```
   The backend server will run at `http://localhost:5000`.

---

### 2. Flutter Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```
3. Create the `.env` configuration file:
   ```bash
   cp .env.example .env
   ```
4. Configure frontend environment variables in `.env`:
   ```env
   # API client URL for backend connection
   APICONFIG=http://localhost:5000

   # Supabase keys (if needed)
   SUPABASE_URL=https://your-supabase-url.supabase.co
   SUPABASE_ANON_KEY=your-supabase-anon-key
   ```
   > **Note on Emulator IPs:**
   > *   **Android Emulator:** Change `APICONFIG` to `http://10.0.2.2:5000`
   > *   **iOS Simulator:** Use `http://localhost:5000`
   > *   **Physical Device:** Use `http://<your-local-ip>:5000` (Make sure your phone and development computer are on the same Wi-Fi network).

5. Run the Flutter app:
   ```bash
   flutter run
   ```

---

## 👥 Default Demo Accounts

For testing the real-time features (like live chatting, read receipts, and typing statuses), we recommend registering two accounts to test on different devices (e.g., Android Emulator vs. iOS Simulator or physical phone).

You can easily register them using the signup flow in the app. Below are recommended credentials to use for verification and demos:

| Account | Default Username | Default Password | Description |
| :--- | :--- | :--- | :--- |
| **Tester 1** | `alice` | `password123` | First account (e.g., active on Android) |
| **Tester 2** | `bob` | `password123` | Second account (e.g., active on iOS or Web) |

---

## 📸 App Screenshots

*Replace the comments below with actual path tags or URLs once screenshots are captured.*

<table>
  <tr>
    <td align="center">
      <!-- login screen screenshot -->
      <img src="https://via.placeholder.com/250x500.png?text=Login+Screen" width="250" alt="Login Screen"/><br/>
      <sub><b>🔐 Authentication Screen</b></sub>
    </td>
    <td align="center">
      <!-- chats screen screenshot -->
      <img src="https://via.placeholder.com/250x500.png?text=Chats+List" width="250" alt="Chats List"/><br/>
      <sub><b>💬 Chats List / DMs</b></sub>
    </td>
    <td align="center">
      <!-- chat room screen screenshot -->
      <img src="https://via.placeholder.com/250x500.png?text=Chat+Room" width="250" alt="Chat Room"/><br/>
      <sub><b>🎧 Chat Room (Real-time Messaging)</b></sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <!-- contacts screen screenshot -->
      <img src="https://via.placeholder.com/250x500.png?text=Contacts+Screen" width="250" alt="Contacts Screen"/><br/>
      <sub><b>👥 Contacts Screen</b></sub>
    </td>
    <td align="center">
      <!-- profile screen screenshot -->
      <img src="https://via.placeholder.com/250x500.png?text=Profile+Settings" width="250" alt="Profile Settings"/><br/>
      <sub><b>⚙️ Profile & Settings</b></sub>
    </td>
  </tr>
</table>

---

