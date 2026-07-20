import { Response } from 'express';
import { userService } from './user.service';
import { AuthRequest } from '../../middleware/auth.middleware';

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
  }
};