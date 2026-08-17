import './db'; // Imports and initializes DB connection first
import dotenv from "dotenv";
dotenv.config();


import express from "express";
import './config/firebase';
import http from "http";
import cors from "cors";
import jwt from "jsonwebtoken";
import path from 'path';
import { Server } from "socket.io";

import { auth } from './middleware/auth.middleware';
import authRouter from "./features/auth/auth.routes";
import chatRouter from "./features/chat/chat.routes";
import { chatSocket } from "./features/chat/chat.socket";
import userRouter from "./features/users/users.routes";
import contactsRoutes from "./features/contacts/contacts.routes";
import settingsRoutes from "./features/settings/settings.routes";

const app = express();

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

io.use((socket, next) => {
  try {
    const token = socket.handshake.auth?.token;

    if (!token) {
      return next(new Error("Unauthorized"));
    }
    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as { id: number };

    (socket as any).user = { id: decoded.id };

    next();
  } catch (err) {
    next(new Error("Unauthorized"));
  }
});

chatSocket(io);

app.use("/api/auth", authRouter);
app.use("/api/chats", auth, chatRouter);
app.use("/api/users", userRouter);
app.use("/api/contacts", auth, contactsRoutes);
app.use("/api/settings", auth, settingsRoutes);

app.get("/", (_, res) => {
  res.send("Chat server is running 🚀");
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Server running on ${PORT}`));