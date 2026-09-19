import './db';
import dotenv from "dotenv";
dotenv.config();

import express, { NextFunction, Request, Response } from "express";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import './config/firebase';
import http from "http";
import cors from "cors";
import multer from "multer";
import { Server } from "socket.io";

import db from './db';
import { auth } from './middleware/auth.middleware';
import { authService } from './features/auth/auth.service';
import authRouter from "./features/auth/auth.routes";
import chatRouter from "./features/chat/chat.routes";
import { chatSocket } from "./features/chat/chat.socket";
import { setIo } from "./config/io";
import userRouter from "./features/users/users.routes";
import contactsRoutes from "./features/contacts/contacts.routes";
import settingsRoutes from "./features/settings/settings.routes";

// A rejected promise inside a socket handler must never take the whole
// server down (Node exits on unhandled rejections by default).
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled promise rejection:', reason);
});
process.on('uncaughtException', (err) => {
  // State may be corrupt after this — log and let Render restart the process.
  console.error('Uncaught exception:', err);
  process.exit(1);
});

const app = express();

// Enable proxy trust for Render (exactly one proxy hop in front of the app)
app.set('trust proxy', 1);
app.disable('x-powered-by');

app.use(helmet());

// Native mobile clients don't use CORS at all. Browsers are only allowed from
// origins listed in CORS_ORIGINS (comma separated); unset = allow any origin.
// Auth is a Bearer header (never a cookie) so `credentials` stays off.
const allowedOrigins = (process.env.CORS_ORIGINS ?? '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);
const corsOrigin = allowedOrigins.length > 0 ? allowedOrigins : '*';

app.use(cors({ origin: corsOrigin }));

// Credential endpoints: tight limit to slow down password guessing.
const credentialLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many attempts, please try again in 15 minutes' },
});

// Everything else under /api/auth (sessions list, /me, logout…)
const authLimiter = rateLimit({
  windowMs: 30 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests from this IP, please try again after 30 minutes' },
});

// Global safety net for the rest of the API
const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 600,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please slow down' },
});

// JSON bodies only ever carry text; files go through multipart (multer).
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ limit: '1mb', extended: true }));

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: corsOrigin,
    methods: ["GET", "POST"]
  },
  transports: ['polling', 'websocket'],
  maxHttpBufferSize: 1e6, // 1MB per socket packet is plenty for text events
});

app.set('io', io);

io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth?.token;

    if (!token || typeof token !== "string") {
      return next(new Error("Unauthorized"));
    }

    const session = await authService.validateSessionToken(token);

    if (!session) {
      return next(new Error("Unauthorized"));
    }

    (socket as any).user = { id: session.userId };
    socket.data = { sessionId: session.sessionId };

    next();
  } catch (err) {
    next(new Error("Unauthorized"));
  }
});

chatSocket(io);
setIo(io); // Make io accessible to controllers via singleton

app.use("/api", apiLimiter);
app.use(["/api/auth/login", "/api/auth/register", "/api/auth/verify-password"], credentialLimiter);
app.use("/api/auth", authLimiter, authRouter);

app.use("/api/chats", auth, chatRouter);
app.use("/api/users", userRouter);
app.use("/api/contacts", auth, contactsRoutes);
app.use("/api/settings", auth, settingsRoutes);

app.get("/", (_, res) => {
  res.send("Chat server is running 🚀");
});

// Unknown routes → JSON (the mobile client rejects non-JSON responses)
app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: 'Not found' });
});

// Central error handler: malformed JSON, oversized uploads, anything thrown
// synchronously in a route. Never leaks stack traces to the client.
app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof multer.MulterError) {
    const message = err.code === 'LIMIT_FILE_SIZE' ? 'File is too large' : 'Invalid upload';
    return res.status(err.code === 'LIMIT_FILE_SIZE' ? 413 : 400).json({ error: message });
  }
  if (err?.type === 'entity.too.large') {
    return res.status(413).json({ error: 'Request body is too large' });
  }
  if (err?.type === 'entity.parse.failed' || err instanceof SyntaxError) {
    return res.status(400).json({ error: 'Malformed JSON body' });
  }
  if (typeof err?.status === 'number' && err.status >= 400 && err.status < 500) {
    return res.status(err.status).json({ error: err.message || 'Bad request' });
  }
  console.error('Unhandled route error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Server running on ${PORT}`));

// Render sends SIGTERM on every deploy — finish in-flight work, then exit.
const shutdown = (signal: string) => {
  console.log(`${signal} received, shutting down gracefully`);
  io.close();
  server.close(() => {
    db.end().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
