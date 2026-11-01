# 💬 Teleflow

**Teleflow** is a real-time messaging app for mobile: a **Flutter** client for **Android & iOS** backed by a **Node.js + TypeScript + Express + Socket.io** server, with **PostgreSQL** (Supabase) for persistence and **Cloudinary** for media.

The client and server communicate over **REST** (`/api`) and **Socket.io** WebSockets: chats, messages, delivery/read receipts, reactions, replies, typing indicators and presence are all handled in real time.

> [!NOTE]
> **Status: v1.0.0 — actively in development.** The backend is deployed on Render (currently `https://chat-backend-gzci.onrender.com`) and the data layer uses a Supabase (PostgreSQL) database. The mobile client is a Flutter app built for Android and iOS. Features are added and refined continuously, so some flows may still be in testing.

---

## ✨ Features

### Real-time messaging
- **1:1 chats** and **group chats** — create groups, rename groups, change group avatar, add/remove members, delete chats/groups.
- **Live delivery & read receipts** — sent (`✓`) → delivered (`✓✓`) → read (blue `✓✓`), tracked per recipient, with group-wide "all members read" aggregation semantics.
- **Presence & typing** — online status, last seen, typing indicators (debounced), unread message badges.
- **Message types** — text, images, videos, voice notes (audio), and general file sharing.
- **Replies, reactions & deletion** — replies quote the original message via a snapshot; emoji reactions are stored in a dedicated `message_reactions` table; messages can be deleted.

### Privacy & security
- **Hide last seen** and **hide read receipts** settings (with reciprocity handled on the backend).
- **Block users** — messages sent while a block was active are persisted with a hidden flag and never delivered to the blocked user (Telegram-style behaviour).

### Auth, sessions & device security
- Register / login / logout / change & verify password.
- **Session management** — list active sessions, revoke a session, terminate all other sessions; sessions expire after inactivity.
- **Login lockout** — after repeated failed attempts, login is temporarily locked.

### Notifications
- **Firebase Cloud Messaging (FCM)** push notifications with a global on/off switch and per-chat mute list; tapping a notification deep-links into the right conversation.

### Local experience
- Local caching of chats, messages, profile and contacts via **Hive**, with session token storage via **flutter_secure_storage**.
- Auto-login and app-lifecycle handling (the socket is kept in the foreground state so backgrounding doesn't mark incoming messages as read behind the user's back).

---

## 🛠️ Technical Stack

### Backend (`backend/`)
| Layer | Technology |
| --- | --- |
| Runtime | Node.js + TypeScript |
| REST API | Express 5 |
| Real-time | Socket.io (WebSocket + long-polling transports) |
| Database | PostgreSQL via Supabase (`pg` pool) — migrations in `backend/migrations/` |
| Media | Multer (memory storage) + Cloudinary |
| Notifications | Firebase Admin SDK (FCM) |
| Auth | BcryptJS password hashing + opaque session tokens (SHA-256 hashed, stored per session) |
| Hardening | Helmet, CORS, rate limiting, Zod validation, body size limits, centralized error handler, graceful shutdown |

### Frontend (`frontend/`)
| Layer | Technology |
| --- | --- |
| Framework | Flutter + Dart (Android & iOS) |
| State management | Riverpod (+ code generation) |
| Navigation | GoRouter |
| Local cache / auth | Hive + flutter_secure_storage |
| Real-time | Socket.io client |
| Notifications | Firebase Messaging + flutter_local_notifications |
| Media | image_picker, file_picker, video_player, just_audio / flutter_sound |
| UI | Custom glassmorphism theme, dark & light palettes, responsive layout (ScreenUtil) |

---

## 📂 Project Structure

```text
Chat-App/
├── backend/
│   ├── migrations/             # SQL migrations (replies, security/performance, receipts, reactions & blocks)
│   ├── src/
│   │   ├── config/              # Firebase Admin, Socket.io server instances
│   │   ├── features/            # auth, chat, contacts, settings, users
│   │   ├── middleware/          # auth + param validation
│   │   ├── services/            # notification service (FCM)
│   │   ├── db.ts                # PostgreSQL pool
│   │   └── index.ts             # Express app + Socket.io server entry
│   ├── package.json
│   └── tsconfig.json

└── frontend/
    └── lib/
        ├── core/                # auth, common, constants, network, storage, theme, utils, widgets
        └── features/            # app_shell, auth, chat, contacts, notification, profile, settings
```

---

## 🚀 Getting Started

### Backend
```bash
cd backend
npm install
npm run dev     # ts-node
npm run build   # tsc
npm start       # node dist
```

The server expects environment variables for the database, storage, Firebase and server settings (e.g. `DATABASE_URL`, Supabase credentials, `CLOUDINARY_*`, `FIREBASE_SERVICE_ACCOUNT`, `PORT`, `CORS_ORIGINS`).

### Frontend
```bash
cd frontend
flutter run
```

The client reads its backend URL from environment variables (`APICONFIG`, `SOCKET_URL`) in `frontend/.env`.

---

## 🗄 Database

SQL migrations live in [`backend/migrations/`](backend/migrations) and are applied to the Supabase project (e.g. via the Supabase SQL editor). Current migrations:

| Migration | Purpose |
| --- | --- |
| `001_message_replies.sql` | Reply-to-message support |
| `002_security_and_performance.sql` | Security/performance hardening (RLS guidance) |
| `003_message_receipts.sql` | Delivery & read receipts |
| `004_reactions_and_block_visibility.sql` | Emoji reactions + persistent block visibility |

---

## 🧪 Testing

- Frontend: Flutter tests live in [`frontend/test/`](frontend/test) (auth, chat, profile, settings, core widgets).
- Backend: small ad-hoc scripts in `backend/` (`test_io.js`, `test_fcm.js`).

---

## 🔗 Useful API areas

- `POST /api/auth/register|login`, `GET /api/auth/me`, `POST /api/auth/logout`, `POST /api/auth/password`, `POST /api/auth/verify-password`
- `GET|POST /api/auth/sessions`, `POST /api/auth/sessions/:id/revoke`, `POST /api/auth/sessions/others`
- `GET /api/chats`, `POST /api/chats/group`, `POST /api/chats/create/:contactId`, `GET /api/chats/:chatId`, `GET /api/chats/:chatId/messages`, `POST /api/chats/:chatId/messages`, `PATCH /api/chats/:chatId/messages/read`
- `PUT /api/chats/:chatId/messages/:messageId/reaction`, `DELETE /api/chats/:chatId/messages/:messageId`
- `GET /api/users/me`, `PATCH /api/users/me`, `POST /api/users/avatar`, `POST /api/users/fcm-token`
- `GET /api/contacts`, `GET /api/contacts/blocked`, `GET /api/contacts/search?q=`, `POST /api/contacts`, `DELETE /api/contacts/:id`, `POST /api/contacts/:id/block`
- `GET /api/settings`, `PATCH /api/settings`

---

## 📝 Notes & status

This project is under active development. Known-stage highlights of the recent work include:

- Per-recipient delivery/read receipts and WhatsApp-style group read aggregation.
- Emoji reactions and reply-to-message support.
- Persistent block visibility for messages sent during a block.
- Session revoke / terminate-other-sessions flows and login lockout.

---

## 🙏 Acknowledgements

Built with Flutter, Node.js, Express, Socket.io, PostgreSQL/Supabase, Cloudinary, Firebase and Riverpod.
