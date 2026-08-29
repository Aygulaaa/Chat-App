import { Router } from "express";
import { auth } from "../../middleware/auth.middleware";
import { validateData } from "../../middleware/auth.middleware";
import {
  registerSchema,
  loginSchema,
  changePasswordSchema,
  verifyPasswordSchema,
} from "./auth.schema";
import {
  register,
  login,
  me,
  logout,
  changePassword,
  verifyPassword,
  getSessions,
  revokeSession,
  terminateOtherSessions,
} from "./auth.controller";

const router = Router();

// --- PUBLIC ROUTES ---
router.post("/register", validateData(registerSchema), register);
router.post("/login", validateData(loginSchema), login);

// --- PROTECTED USER ROUTES ---
router.get("/me", auth, me);
router.post("/logout", auth, logout);
router.patch("/password", auth, validateData(changePasswordSchema), changePassword);
router.post("/verify-password", auth, validateData(verifyPasswordSchema), verifyPassword);

// --- PROTECTED SESSION MANAGEMENT ROUTES ---
router.get("/sessions", auth, getSessions);
router.delete("/sessions/others", auth, terminateOtherSessions);
router.delete("/sessions/:id", auth, revokeSession);

console.log("AUTH ROUTES FILE EXECUTED");

export default router;