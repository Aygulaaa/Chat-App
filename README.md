# 💬 Teleflow - Full-Stack Real-Time Chat Application

Teleflow is a production-ready, real-time messaging application engineered for seamless cross-platform communication. Built with a focus on scalable architecture and user experience, the mobile frontend is developed in **Flutter** (utilizing Clean Architecture and Riverpod), while the robust backend is powered by **Node.js**, **Express**, and **Socket.io**, fully deployed on **Render** with a **Supabase** (PostgreSQL) database.

---

## 🌟 Key Features

### Real-Time Communication
* **Granular Message Statuses:** Live updates for Sent, Delivered, and Read receipts.
* **Live Presence:** Real-time online status and typing indicators.
* **Dynamic Chat Environments:** Full support for both direct messaging (1-on-1) and group chats.
* **Media & File Sharing:** Secure, fast uploads for photos and videos.

### User Privacy & Control
* **Advanced Privacy Settings:** Options to toggle "Hide Last Seen" and "Hide Read Receipts".
* **Contact Management:** Robust global user search, add to contacts, and the ability to block/unblock users.
* **Notification Management:** Mute push notifications for specific chats or globally.

### UI / UX Design
* **Glassmorphic Interface:** A visually stunning, modern UI with smooth micro-interactions.
* **Adaptive Theming:** Fully responsive Dark and Light modes.
* **Cross-Platform Consistency:** Rigorously tested and optimized across iOS and Android environments.

---

## 🛠️ Technical Architecture

### Backend (Deployed on Render)
| Technology | Purpose |
| :--- | :--- |
| **Node.js & TypeScript** | Strongly-typed, asynchronous runtime environment. |
| **Express** | REST API framework for authentication and user management. |
| **Socket.io** | WebSocket server managing low-latency, real-time event broadcasting. |
| **Supabase (PostgreSQL)** | Cloud-hosted relational database for secure, scalable persistence. |
| **Cloudinary & Multer** | Optimized media upload pipeline and cloud storage hosting. |
| **JWT & BcryptJS** | Secure, token-based authentication and password hashing. |

### Frontend (Flutter)
| Technology | Purpose |
| :--- | :--- |
| **Flutter & Dart** | Cross-platform mobile framework leveraging Clean Architecture. |
| **Riverpod / BLoC** | Reactive state management and dependency injection. |
| **Socket.io Client** | Persistent real-time connection to the backend server. |
| **Flutter Secure Storage** | Encrypted on-device storage for session tokens. |

---

## 📂 Project Structure (Clean Architecture)

## 📂 Project Architecture

```text
Chat-App/
├── backend/                      # Node.js & TypeScript Express server
│   ├── src/
│   │   ├── config/               # Server configuration & environment setup
│   │   ├── features/             # Modular backend feature domains
│   │   │   ├── auth/             # Authentication & user registration
│   │   │   ├── chat/             # Real-time Socket.io handlers & messaging
│   │   │   ├── contacts/         # Contact management & blocking features
│   │   │   ├── settings/         # Privacy options & user preferences
│   │   │   └── users/            # Profile updates & avatar management
│   │   ├── middleware/           # JWT authentication & error middleware
│   │   ├── services/             # Firebase FCM & third-party integrations
│   │   ├── db.ts                 # PostgreSQL database pool (Supabase)
│   │   ├── firebase.ts           # Firebase Admin SDK initialization
│   │   └── index.ts              # Server entry point (Express & Socket.io)
│   ├── package.json              # Backend dependencies
│   └── tsconfig.json             # TypeScript compiler options
│
└── frontend/                     # Flutter cross-platform mobile application
    ├── android/                  # Native Android build & Gradle configuration
    ├── ios/                      # Native iOS project & Xcode configuration
    ├── lib/
    │   ├── core/                 # Shared infrastructure & foundational utilities
    │   │   ├── auth/             # Core auth state & session storage
    │   │   ├── common/           # Shared widgets & UI components
    │   │   ├── constants/        # Global constants, routes, & API endpoints
    │   │   ├── network/          # REST client & Socket.io client setup
    │   │   ├── storage/          # Secure key-value storage wrappers
    │   │   ├── theme/            # Light & Dark mode glassmorphic styling
    │   │   └── utils/            # Helper extensions & utilities
    │   ├── features/             # Domain-driven feature modules (Clean Architecture)
    │   │   ├── app_shell/        # Main navigation shell & bottom bar
    │   │   ├── auth/             # Login & signup UI flows
    │   │   ├── chat/             # Messaging rooms, attachments, & live status
    │   │   ├── contacts/         # Contacts view & search functionality
    │   │   ├── notification/     # FCM push notification handlers
    │   │   ├── profile/          # Profile view & customization
    │   │   └── settings/         # Privacy toggles (hide read receipts, last seen)
    │   └── main.dart             # Flutter app entry point
    └── pubspec.yaml              # Flutter dependencies & app metadata