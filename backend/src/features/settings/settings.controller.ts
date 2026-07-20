import { Response } from 'express';
import { settingsService } from './settings.service';
import { AuthRequest } from '../../middleware/auth.middleware';

export const settingsController = {
  async getSettings(req: AuthRequest, res: Response) {
    try {
      const settings = await settingsService.getSettings(req.user!.id);
      res.json(settings);
    } catch (err) {
      res.status(500).json({ error: 'Failed to fetch settings. Error:', err });
    }
  },

  async updateSettings(req: AuthRequest, res: Response) {
    try {
      const updated = await settingsService.updateSettings(
        req.user!.id,
        req.body,
      );
      res.json(updated);
    } catch (err: any) {
      res.status(400).json({ error: err.message ?? 'Failed to update settings. Error:', err });
    }
  },
};