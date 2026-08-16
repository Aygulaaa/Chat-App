import { Response } from 'express';
import { userService } from './user.service';
import { AuthRequest } from '../../middleware/auth.middleware';
import db from '../../db';

export const userController = {
  async getMe(req: AuthRequest, res: Response) {
    try {
      const userId = req.user!.id;
      const user = await userService.getProfile(userId);
      res.json(user);
    } catch (err) {
      res.status(500).json({ error: 'Failed to fetch profile. Error:', err });
    }
  },

  async getUserById(req: AuthRequest, res: Response) {
    try {
      const userId = Number(req.params.userId);
      if (!userId || isNaN(userId)) {
        return res.status(400).json({ error: 'Invalid userId' });
      }
      const user = await userService.getProfile(userId);
      if (!user) return res.status(404).json({ error: 'User not found' });
      res.json(user);
    } catch (err) {
      res.status(500).json({ error: 'Failed to fetch user' });
    }
  },

  async updateMe(req: AuthRequest, res: Response) {
    try {
      const userId = req.user!.id;
      const { username, bio, birthDate } = req.body;
      const updatedUser = await userService.updateProfile(userId, username, bio, birthDate);
      res.json(updatedUser);
    } catch (err) {
      res.status(500).json({ error: 'Failed to update profile. Error:', err });
    }
  },

  async updateAvatar(req: AuthRequest, res: Response) {
    try {
      if (!req.file) return res.status(400).json({ error: "No image provided" });

      const userId = req.user!.id;

      const imageUrl = await userService.uploadToCloudinary(req.file.buffer);

      const updatedUser = await userService.updateAvatar(userId, imageUrl);

      res.json(updatedUser);
    } catch (err) {
      console.error("Controller Error (updateAvatar):", err);
      res.status(500).json({ error: "Upload failed" });
    }
  },

  async pushNotification(req: AuthRequest, res: Response) {
    try {
      const userId = (req as any).user.id;
      const { fcmToken } = req.body;

      if (!fcmToken) {
        return res.status(400).json({ error: 'fcmToken is required' });
      }

      await db.query('UPDATE users SET fcm_token = $1 WHERE id = $2', [fcmToken, userId]);

      return res.status(200).json({ success: true, message: 'FCM Token saved successfully' });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
};