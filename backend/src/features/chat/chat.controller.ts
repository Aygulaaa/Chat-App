import { Response } from 'express';
import { chatService } from '../chat/chat.service';
import { AuthRequest } from '../../middleware/auth.middleware';
import db from '../../db';
import { sendPushToMembers } from '../../services/notificationService';

// Helper to broadcast socket events to non-blocked members in 1 SQL query
async function broadcastToChatMembers(
  io: any,
  chatId: number,
  senderId: number,
  event: string,
  payload: any
) {
  if (!io) return;

  const membersResult = await db.query(
    `SELECT cm.user_id 
     FROM chat_members cm
     LEFT JOIN contacts c ON 
       ((c.user_id = $1 AND c.contact_user_id = cm.user_id) OR (c.user_id = cm.user_id AND c.contact_user_id = $1))
       AND c.status = 'blocked'
     WHERE cm.chat_id = $2 
       AND c.user_id IS NULL`,
    [senderId, chatId]
  );

  for (const row of membersResult.rows) {
    io.to(`user_${row.user_id}`).emit(event, payload);
  }
}

// Fetch sender details in a single clean query
async function getSenderName(senderId: number): Promise<string> {
  const result = await db.query(
    `SELECT username, name FROM users WHERE id = $1`,
    [senderId]
  );
  const user = result.rows[0];
  return user?.name || user?.username || 'New Message';
}

export const chatController = {
  async getChats(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chats = await chatService.getChats(req.user.id);
      res.json(chats);
    } catch (err) {
      console.error('🔥 SQL ERROR IN getChats:', err);
      res.status(500).json({ error: 'Failed to fetch chats.' });
    }
  },

  async getChat(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const chat = await chatService.getChat(chatId, req.user.id);
      if (!chat) return res.status(404).json({ error: 'Chat not found' });
      res.json(chat);
    } catch (err) {
      console.error('🔥 SQL ERROR IN getChat:', err);
      res.status(500).json({ error: 'Failed to fetch chat.' });
    }
  },

  async getMessages(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const messages = await chatService.getMessages(chatId, req.user.id);
      res.json(messages);
    } catch (err) {
      res.status(500).json({ error: 'Failed to fetch messages.' });
    }
  },

  async sendMessage(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });

      const chatId = Number(req.params.chatId);
      const senderId = req.user.id;
      const { text } = req.body;

      if (!text || typeof text !== 'string' || !text.trim()) {
        return res.status(400).json({ error: 'Message text cannot be empty' });
      }

      const message = await chatService.sendMessage(chatId, senderId, text.trim());
      const io = req.app.get('io');

      // Async executions run cleanly without redundant queries
      await broadcastToChatMembers(io, chatId, senderId, 'message', message);
      const senderName = await getSenderName(senderId);
      await sendPushToMembers(io ?? null, chatId, senderId, senderName, text.trim(), message.id);

      const finalMessage = (await chatService.getMessageById(message.id, senderId)) || message;
      res.json(finalMessage);
    } catch (err: any) {
      res.status(err.status || 500).json({ error: err.message || 'Failed to send message.' });
    }
  },

  async sendFileMessage(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      if (!req.file) return res.status(400).json({ error: 'No file provided' });

      const chatId = Number(req.params.chatId);
      const senderId = req.user.id;

      const message = await chatService.sendFileMessage(
        chatId,
        senderId,
        req.file.buffer,
        req.file.originalname,
        req.file.mimetype,
        req.file.size
      );

      const io = req.app.get('io');
      await broadcastToChatMembers(io, chatId, senderId, 'message', message);
      const senderName = await getSenderName(senderId);
      await sendPushToMembers(io ?? null, chatId, senderId, senderName, req.file.originalname, message.id);

      const finalMessage = (await chatService.getMessageById(message.id, senderId)) || message;
      res.json(finalMessage);
    } catch (err: any) {
      console.error('File upload error:', err);
      res.status(err.status || 500).json({ error: err.message || 'Failed to send file.' });
    }
  },

  async createChat(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const contactId = Number(req.params.contactId);
      const chat = await chatService.createChat(req.user.id, contactId);
      res.json(chat);
    } catch (err: any) {
      res.status(400).json({ error: err.message ?? 'Failed to create chat.' });
    }
  },

  async markMessagesRead(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const messages = await chatService.markMessagesRead(chatId, req.user.id);
      res.json(messages);
    } catch (err) {
      res.status(500).json({ error: 'Failed to mark messages as read.' });
    }
  },

  async createGroupChat(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const { name, memberIds, avatar } = req.body;
      if (!name || !Array.isArray(memberIds) || !memberIds.length) {
        return res.status(400).json({ error: 'Name and non-empty memberIds list required' });
      }
      const chat = await chatService.createGroupChat(req.user.id, name, memberIds, avatar);
      res.json(chat);
    } catch (err: any) {
      res.status(500).json({ error: err.message ?? 'Failed to create group' });
    }
  },

  async addMember(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const { userId } = req.body;
      if (!userId || isNaN(Number(userId))) {
        return res.status(400).json({ error: 'Valid userId required' });
      }
      const result = await chatService.addMember(chatId, Number(userId));
      res.json(result);
    } catch (err) {
      res.status(500).json({ error: 'Failed to add member' });
    }
  },

  async removeMember(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const userId = Number(req.params.userId);
      await chatService.removeMember(chatId, userId);
      res.json({ success: true });
    } catch (err) {
      res.status(500).json({ error: 'Failed to remove member' });
    }
  },

  async updateGroupInfo(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const { name } = req.body;
      let avatarUrl = req.body.avatar;

      if (req.file) {
        avatarUrl = await chatService.uploadGroupAvatar(
          req.file.buffer,
          req.file.originalname,
          req.file.mimetype
        );
      }

      const result = await chatService.updateGroupInfo(chatId, name, avatarUrl);
      res.json(result);
    } catch (err) {
      res.status(500).json({ error: 'Failed to update group' });
    }
  },

  async deleteMessage(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const messageId = Number(req.params.messageId);
      const senderId = req.user.id;

      const deleted = await chatService.deleteMessage(messageId, senderId);
      if (!deleted) {
        return res.status(404).json({ error: 'Message not found or not authorized' });
      }

      const io = req.app.get('io');
      await broadcastToChatMembers(io, chatId, senderId, 'message_deleted', { messageId, chatId });

      res.json({ success: true, messageId, chatId });
    } catch (err) {
      res.status(500).json({ error: 'Failed to delete message' });
    }
  },

  async deleteChat(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      await chatService.deleteChat(chatId);
      res.json({ success: true });
    } catch (err) {
      res.status(500).json({ error: 'Failed to delete chat' });
    }
  },

  async deleteGroup(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const requesterId = req.user.id;

      const { memberIds } = await chatService.deleteGroup(chatId, requesterId);

      const io = req.app.get('io');
      if (io) {
        for (const memberId of memberIds) {
          io.to(`user_${memberId}`).emit('group_deleted', { chatId });
        }
      }

      res.json({ success: true, chatId });
    } catch (err: any) {
      const status =
        err.message === 'Group not found' ? 404 :
        err.message === 'Only the group creator can delete the group' ? 403 :
        err.message === 'This is not a group chat' ? 400 : 500;
      res.status(status).json({ error: err.message ?? 'Failed to delete group' });
    }
  },
};