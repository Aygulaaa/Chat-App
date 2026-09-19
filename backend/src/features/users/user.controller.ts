import { Response } from 'express';
import { userService } from './user.service';
import { AuthRequest } from '../../middleware/auth.middleware';
import db from '../../db';

// Same rules as registration (auth.service) — the profile editor must not be
// a way around them, but also must not reject names registration accepted.
const isValidUsername = (name: string) =>
  name.length >= 3 && name.length <= 30 && !/[\u0000-\u001f\u007f]/.test(name);
const MAX_BIO_LENGTH = 300;

export const userController = {
  async getMe(req: AuthRequest, res: Response) {
    try {
      const userId = req.user!.id;
      const user = await userService.getProfile(userId, userId);
      res.json(user);
    } catch (err) {
      console.error('getMe error:', err);
      res.status(500).json({ error: 'Failed to fetch profile' });
    }
  },

  async getUserById(req: AuthRequest, res: Response) {
    try {
      const userId = Number(req.params.userId);
      const requestingUserId = req.user!.id;
      if (!Number.isInteger(userId) || userId <= 0) {
        return res.status(400).json({ error: 'Invalid userId' });
      }
      const user = await userService.getProfile(userId, requestingUserId);
      if (!user) return res.status(404).json({ error: 'User not found' });
      res.json(user);
    } catch (err) {
      console.error('getUserById error:', err);
      res.status(500).json({ error: 'Failed to fetch user' });
    }
  },

  async updateMe(req: AuthRequest, res: Response) {
    try {
      const userId = req.user!.id;
      const { username, bio, birthDate } = req.body ?? {};

      if (typeof username !== 'string') {
        return res.status(400).json({ error: 'Username is required' });
      }
      // Login lowercases the username before looking it up, so a mixed-case
      // name saved here would lock the user out of their own account.
      const cleanUsername = username.trim().toLowerCase();
      if (!isValidUsername(cleanUsername)) {
        return res.status(400).json({ error: 'Username must be between 3 and 30 characters long' });
      }

      if (bio != null && typeof bio !== 'string') {
        return res.status(400).json({ error: 'Invalid bio' });
      }
      const cleanBio = typeof bio === 'string' ? bio.trim() : null;
      if (cleanBio && cleanBio.length > MAX_BIO_LENGTH) {
        return res.status(400).json({ error: `Bio must be under ${MAX_BIO_LENGTH} characters` });
      }

      let cleanBirthDate: string | null = null;
      if (birthDate != null && birthDate !== '') {
        const parsed = typeof birthDate === 'string' ? new Date(birthDate) : null;
        if (!parsed || isNaN(parsed.getTime()) || parsed > new Date() || parsed.getFullYear() < 1900) {
          return res.status(400).json({ error: 'Invalid birth date' });
        }
        cleanBirthDate = parsed.toISOString().slice(0, 10);
      }

      const updatedUser = await userService.updateProfile(userId, cleanUsername, cleanBio, cleanBirthDate);
      res.json(updatedUser);
    } catch (err: any) {
      if (err?.code === '23505') {
        return res.status(400).json({ error: 'Username is already taken' });
      }
      console.error('updateMe error:', err);
      res.status(500).json({ error: 'Failed to update profile' });
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
      const userId = req.user!.id;
      const { fcmToken } = req.body ?? {};

      if (typeof fcmToken !== 'string' || !fcmToken.trim() || fcmToken.length > 4096) {
        return res.status(400).json({ error: 'fcmToken is required' });
      }

      // A device token belongs to ONE account. Without the first statement, a
      // phone that logs into account B keeps receiving account A's messages.
      await db.query('UPDATE users SET fcm_token = NULL WHERE fcm_token = $1 AND id != $2', [fcmToken, userId]);
      await db.query('UPDATE users SET fcm_token = $1 WHERE id = $2', [fcmToken, userId]);

      return res.status(200).json({ success: true, message: 'FCM Token saved successfully' });
    } catch (error: any) {
      console.error('pushNotification error:', error);
      return res.status(500).json({ error: 'Failed to save push token' });
    }
  },

  /** Called on logout so a signed-out device stops receiving this user's pushes. */
  async clearPushToken(req: AuthRequest, res: Response) {
    try {
      await db.query('UPDATE users SET fcm_token = NULL WHERE id = $1', [req.user!.id]);
      return res.status(200).json({ success: true });
    } catch (error: any) {
      console.error('clearPushToken error:', error);
      return res.status(500).json({ error: 'Failed to clear push token' });
    }
  }
};
