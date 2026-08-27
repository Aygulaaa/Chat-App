import { Router } from "express";
import { auth } from "../../middleware/auth.middleware";
import {
  register,
  login,
  me,
  logout,
  changePassword,
  verifyPassword,
} from "./auth.controller";

const router = Router();

router.post("/register", register);
router.post("/login", login);
router.get("/me", auth, me);
router.post("/logout", logout);
router.patch("/password", auth, changePassword);
router.post("/verify-password", auth, verifyPassword);

console.log("AUTH ROUTES FILE EXECUTED");
export default router;