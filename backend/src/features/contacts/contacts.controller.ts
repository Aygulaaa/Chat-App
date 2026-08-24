import { Response } from 'express';
import { contactsService } from './contacts.service';
import { AuthRequest } from '../../middleware/auth.middleware';

export const contactsController = {
  async getContacts(req: AuthRequest, res: Response) {
    try {
      const contacts = await contactsService.getContacts(req.user!.id);
      res.json(contacts);
    } catch (err) {
      res.status(500).json({ error: 'Failed to fetch contacts' });
    }
  },
  
  async getBlockedContacts(req: AuthRequest, res: Response) {
    try {
      const blocked = await contactsService.getBlockedContacts(req.user!.id);
      res.json(blocked);
    } catch (err) {
      res.status(500).json({ error: 'Failed to fetch blocked contacts' });
    }
  },

  async searchUsers(req: AuthRequest, res: Response) {
    try {
      const query = req.query.q as string ?? '';
      const users = await contactsService.searchUsers(query, req.user!.id);
      res.json(users);
    } catch (err) {
      res.status(500).json({ error: 'Search failed' });
    }
  },

  async addContact(req: AuthRequest, res: Response) {
    try {
      const contactId = Number(req.params.contactId);
      const result = await contactsService.addContact(req.user!.id, contactId);
      res.json(result);
    } catch (err: any) {
      res.status(400).json({ error: err.message ?? 'Failed to add contact' });
    }
  },

  async removeContact(req: AuthRequest, res: Response) {
    try {
      const contactId = Number(req.params.contactId);
      await contactsService.removeContact(req.user!.id, contactId);
      res.json({ success: true });
    } catch (err) {
      res.status(500).json({ error: 'Failed to remove contact' });
    }
  },

  async blockUser(req: AuthRequest, res: Response) {
    try {
      const contactId = Number(req.params.contactId);
      const result = await contactsService.blockUser(req.user!.id, contactId);
      
      const io = req.app.get('io');
      if (io) {
        io.to(`user_${contactId}`).emit('user_status', { userId: req.user!.id, status: 'offline', lastSeen: null, lastSeenFuzzy: null });
        io.to(`user_${req.user!.id}`).emit('user_status', { userId: contactId, status: 'offline', lastSeen: null, lastSeenFuzzy: null });
      }

      res.json(result);
    } catch (err: any) {
      res.status(400).json({ error: err.message ?? 'Failed to block user' });
    }
  },

  async unblockUser(req: AuthRequest, res: Response) {
    try {
      const contactId = Number(req.params.contactId);
      await contactsService.unblockUser(req.user!.id, contactId);
      res.json({ success: true });
    } catch (err) {
      res.status(500).json({ error: 'Failed to unblock user' });
    }
  },
};