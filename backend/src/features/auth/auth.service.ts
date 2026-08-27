import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import * as authRepository from "./auth.repository";
import { settingsRepository } from "../settings/settings.repository";

const JWT_SECRET = process.env.JWT_SECRET as string;

export const register = async ({ username, password }: any) => {
  if (!username || !password) {
    throw new Error("Username and password are required");
  }
  const existing = await authRepository.findByUsername(username);
  if (existing) {
    throw new Error("User already exists");
  }

  const hashed = await bcrypt.hash(password, 10);

  const user = await authRepository.createUser(username, hashed);

  const token = jwt.sign({ id: user.id }, JWT_SECRET, { expiresIn: "7d" });
  await settingsRepository.createDefaults(user.id);

  return {
    token,
    data: user,
  };
};

export const login = async ({ username, password }: any) => {
  const user = await authRepository.findByUsername(username);

  if (!user) throw new Error("User not found");

  const isMatch = await bcrypt.compare(password, user.password);
  if (!isMatch) throw new Error("Wrong password");

  const token = jwt.sign({ id: user.id }, JWT_SECRET, { expiresIn: "7d" });

  return {
    token,
    data: { id: user.id, username: user.username },
  };
};

export const getCurrentUser = async (userId?: number) => {
  if (!userId) throw new Error("Not authenticated");

  const user = await authRepository.findById(userId);
  if (!user) throw new Error("User not found");
  
  const { password, ...userWithoutPassword } = user;
  return userWithoutPassword;
};

export const changePassword = async (userId: number, currentPassword: string, newPassword: string) => {
  const user = await authRepository.findById(userId);
  if (!user) throw new Error("User not found");

  const isMatch = await bcrypt.compare(currentPassword, user.password);
  if (!isMatch) throw new Error("Incorrect current password");

  const hashed = await bcrypt.hash(newPassword, 10);
  const updatedUser = await authRepository.updatePassword(userId, hashed);

  return { success: true };
};

export const verifyPassword = async (userId: number, passwordToCheck: string) => {
  const user = await authRepository.findById(userId);
  if (!user) throw new Error("User not found");

  const isMatch = await bcrypt.compare(passwordToCheck, user.password);
  if (!isMatch) throw new Error("Incorrect current password");

  return { success: true };
};