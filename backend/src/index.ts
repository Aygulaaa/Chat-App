import './db'; // Imports and initializes DB connection first
import dotenv from "dotenv";
dotenv.config();

import express from "express";
import helmet from "helmet"; // ✅ Added Helmet security headers
import rateLimit from "express-rate-limit"; // ✅ Added Brute-force rate limiting
import './config/firebase';
import http from "http";
import cors from "cors";
import jwt from "jsonwebtoken";
import path from 'path';
import { Server } from "socket.io";

import { auth } from './middleware/auth.middleware';
import { authService } from './features/auth/auth.service';
import authRouter from "./features/auth/auth.routes";
import chatRouter from "./features/chat/chat.routes";
import { chatSocket } from "./features/chat/chat.socket";
import userRouter from "./features/users/users.routes";
import contactsRoutes from "./features/contacts/contacts.routes";
import settingsRoutes from "./features/settings/settings.routes";

const app = express();

// ✅ Apply Helmet security headers
app.use(helmet());
app.set('trust proxy', 1);
// ✅ Apply Brute-force protection specifically to auth routes
const authLimiter = rateLimit({
  windowMs: 30 * 60 * 1000, // 30 minutes
  max: 20,                  // Limit each IP to 20 requests per windowMs
  standardHeaders: true,    
  legacyHeaders: false,     
  message: { error: 'Too many requests from this IP, please try again after 30 minutes' },
});

app.use(cors({
  origin: '*', 
  credentials: true,
}));

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use("/uploads", express.static(path.join(process.cwd(), "uploads")));

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  },
  transports: ['polling', 'websocket'],
});

app.set('io', io);

io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth?.token;

    if (!token) {
      return next(new Error("Unauthorized"));
    }
    
    const session = await authService.validateSessionToken(token);
    
    if (!session) {
      return next(new Error("Unauthorized"));
    }

    (socket as any).user = { id: session.userId };

    next();
  } catch (err) {
    next(new Error("Unauthorized"));
  }
});

chatSocket(io);

// ✅ Applied authLimiter to protect authentication endpoints from brute-force attacks
app.use("/api/auth", authLimiter, authRouter);

app.use("/api/chats", auth, chatRouter);
app.use("/api/users", userRouter);
app.use("/api/contacts", auth, contactsRoutes);
app.use("/api/settings", auth, settingsRoutes);

app.get("/", (_, res) => {
  res.send("Chat server is running 🚀");
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Server running on ${PORT}`));