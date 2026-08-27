import { Request, Response } from "express";
import * as authService from "./auth.service";
import { AuthRequest } from "../../middleware/auth.middleware";

export const register = async (req: Request, res: Response) => {
  try {
    const user = await authService.register(req.body);

    res.status(201).json({
      token: user.token,  
      user: user.data,
    });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
};

export const login = async (req: Request, res: Response) => {
  try {
    const user = await authService.login(req.body);

    res.json({
      token: user.token,
      user: user.data,
    });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
};

export const me = async (req: AuthRequest, res: Response) => {
  try {
    const user = await authService.getCurrentUser(req.user?.id);

    res.json(user);
  } catch (error: any) {
    res.status(401).json({ error: error.message });
  }
};

export const logout = async (_req: Request, res: Response) => {
  res.json({ message: "Logged out successfully" });
};

export const changePassword = async (req: AuthRequest, res: Response) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: "Current and new password are required" });
    }

    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const result = await authService.changePassword(userId, currentPassword, newPassword);
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
};

export const verifyPassword = async (req: AuthRequest, res: Response) => {
  try {
    const { currentPassword } = req.body;
    if (!currentPassword) {
      return res.status(400).json({ error: "Current password is required" });
    }

    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const result = await authService.verifyPassword(userId, currentPassword);
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
};