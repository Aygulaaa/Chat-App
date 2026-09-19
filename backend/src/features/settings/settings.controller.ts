import { Response } from 'express';
import { settingsService } from './settings.service';
import { AuthRequest } from '../../middleware/auth.middleware';

export const settingsController = {
  async getSettings(req: AuthRequest, res: Response) {
    try {
      const settings = await settingsService.getSettings(req.user!.id);
      res.json(settings);
    } catch (err) {
      console.error('getSettings error:', err);
      res.status(500).json({ error: 'Failed to fetch settings' });
    }
  },

  async updateSettings(req: AuthRequest, res: Response) {
    try {
      // Whitelist + type-check: only known keys with the right type get through
      const body = req.body ?? {};
      const updates: Record<string, boolean | string> = {};

      for (const key of ['notificationsEnabled', 'hideLastSeen', 'hideReadReceipts'] as const) {
        if (body[key] === undefined) continue;
        if (typeof body[key] !== 'boolean') {
          return res.status(400).json({ error: `${key} must be true or false` });
        }
        updates[key] = body[key];
      }
      if (body.theme !== undefined) {
        if (body.theme !== 'light' && body.theme !== 'dark') {
          return res.status(400).json({ error: "theme must be 'light' or 'dark'" });
        }
        updates.theme = body.theme;
      }
      if (Object.keys(updates).length === 0) {
        return res.status(400).json({ error: 'No fields to update' });
      }

      const updated = await settingsService.updateSettings(req.user!.id, updates);
      res.json(updated);
    } catch (err: any) {
      console.error('updateSettings error:', err);
      res.status(500).json({ error: 'Failed to update settings' });
    }
  },
};