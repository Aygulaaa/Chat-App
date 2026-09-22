import { Response } from 'express';
import { chatService } from '../chat/chat.service';
import { chatRepository, ChatError } from '../chat/chat.repository';
import { AuthRequest } from '../../middleware/auth.middleware';
import db from '../../db';
import { sendPushToMembers } from '../../services/notificationService';
import { receipts } from './chat.receipts';

export const MAX_MESSAGE_LENGTH = 4000;
const MAX_GROUP_NAME_LENGTH = 100;
const MAX_GROUP_MEMBERS = 256;

/**
 * Sends the error to the client. Only `ChatError`s carry text that is safe to
 * show; everything else (pg errors, Cloudinary errors…) is logged and replaced
 * by the generic fallback so internals never leak.
 */
function fail(res: Response, err: unknown, fallback: string, tag: string) {
  if (err instanceof ChatError) {
    return res.status(err.status).json({ error: err.message });
  }
  console.error(`${tag} error:`, err);
  return res.status(500).json({ error: fallback });
}

/** Accepts 12 or "12"; rejects 0, negatives, floats, NaN and junk. */
export function parseId(value: unknown): number | null {
  if (value === undefined || value === null || value === '') return null;
  const n = Number(value);
  return Number.isInteger(n) && n > 0 ? n : null;
}

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
    `SELECT username FROM users WHERE id = $1`,
    [senderId]
  );
  const user = result.rows[0];
  return  user?.username || 'New Message';
}

/**
 * Fan-out after a message is stored. Runs AFTER the HTTP response is sent so a
 * slow FCM call can't delay (or fail) the sender's request.
 */
function deliverInBackground(
  io: any,
  chatId: number,
  senderId: number,
  message: any,
  pushBody: string
) {
  (async () => {
    await broadcastToChatMembers(io, chatId, senderId, 'message', message);
    const senderName = await getSenderName(senderId);
    await sendPushToMembers(io ?? null, chatId, senderId, senderName, pushBody, message.id);
  })().catch((err) => console.error('message fan-out error:', err));
}

export const chatController = {
  async getChats(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      // Loading the chat list means this device is online and has (or is about
      // to have) everything addressed to it.
      receipts.emitDelivered(req.app.get('io'), await receipts.recordDelivered(req.user.id));
      const chats = await chatService.getChats(req.user.id);
      res.json(chats);
    } catch (err) {
      fail(res, err, 'Failed to fetch chats.', 'getChats');
    }
  },

  async getChat(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const chat = await chatService.getChat(chatId, req.user.id);
      res.json(chat);
    } catch (err) {
      fail(res, err, 'Failed to fetch chat.', 'getChat');
    }
  },

  async getMessages(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);

      if (!(await chatService.isMember(chatId, req.user.id))) {
        return res.status(404).json({ error: 'Chat not found' });
      }

      // Pagination: ?limit=50&before=<oldest message id the client has>
      const limit = parseId(req.query.limit) ?? 50;
      const beforeId = parseId(req.query.before) ?? undefined;

      receipts.emitDelivered(
        req.app.get('io'),
        await receipts.recordDelivered(req.user.id, { chatId })
      );
      const messages = await chatService.getMessages(chatId, req.user.id, limit, beforeId);
      res.json(messages);
    } catch (err) {
      fail(res, err, 'Failed to fetch messages.', 'getMessages');
    }
  },

  async sendMessage(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });

      const chatId = Number(req.params.chatId);
      const senderId = req.user.id;
      const { text, replyToId } = req.body ?? {};

      if (!text || typeof text !== 'string' || !text.trim()) {
        return res.status(400).json({ error: 'Message text cannot be empty' });
      }
      const cleanText = text.trim();
      if (cleanText.length > MAX_MESSAGE_LENGTH) {
        return res.status(400).json({ error: `Message is too long (max ${MAX_MESSAGE_LENGTH} characters)` });
      }

      const message = await chatService.sendMessage(chatId, senderId, cleanText, parseId(replyToId));

      res.json(message);
      deliverInBackground(req.app.get('io'), chatId, senderId, message, cleanText);
    } catch (err) {
      fail(res, err, 'Failed to send message.', 'sendMessage');
    }
  },

  async sendFileMessage(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      if (!req.file) return res.status(400).json({ error: 'No file provided' });

      const chatId = Number(req.params.chatId);
      const senderId = req.user.id;
      // Path separators / control chars have no business in a display name
      const originalName =
        (req.file.originalname || 'file').replace(/[\/\\\u0000-\u001f]/g, '_').slice(0, 255) || 'file';

      const message = await chatService.sendFileMessage(
        chatId,
        senderId,
        req.file.buffer,
        originalName,
        req.file.mimetype,
        req.file.size,
        parseId(req.body?.replyToId)
      );

      res.json(message);
      deliverInBackground(req.app.get('io'), chatId, senderId, message, `📎 ${originalName}`);
    } catch (err) {
      fail(res, err, 'Failed to send file.', 'sendFileMessage');
    }
  },

  async createChat(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const contactId = Number(req.params.contactId);
      const chat = await chatService.createChat(req.user.id, contactId);
      res.json(chat);
    } catch (err) {
      fail(res, err, 'Failed to create chat.', 'createChat');
    }
  },

  async markMessagesRead(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      if (!(await chatService.isMember(chatId, req.user.id))) {
        return res.status(404).json({ error: 'Chat not found' });
      }
      const outcome = await receipts.recordRead(req.user.id, chatId);
      await receipts.emitRead(req.app.get('io'), req.user.id, chatId, outcome);
      res.json({ success: true, readCount: outcome.readIds.length });
    } catch (err) {
      fail(res, err, 'Failed to mark messages as read.', 'markMessagesRead');
    }
  },

  /**
   * Add / replace / remove my emoji reaction on a message. Everyone who can
   * see the message is told, each of them getting the list with reactions
   * from people they block left out.
   */
  async setReaction(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const messageId = Number(req.params.messageId);
      const emoji = typeof req.body?.emoji === 'string' ? req.body.emoji : '';

      const requesterId = req.user.id;
      const result = await chatService.setReaction(messageId, requesterId, emoji);

      // Everyone gets the list with reactions from people they block removed
      // — including the person who just reacted, whose HTTP answer would
      // otherwise race (and win) against their own filtered socket event.
      const reactorIds = result.reactions.map((r) => Number(r.userId));
      const blocked = await chatRepository.blockedPairs([
        ...new Set([...result.recipientIds, ...reactorIds, requesterId]),
      ]);
      const visibleTo = (memberId: number) =>
        result.reactions.filter(
          (r) => !blocked.has(`${memberId}:${Number(r.userId)}`)
        );

      res.json({
        messageId,
        chatId: result.chatId,
        reactions: visibleTo(requesterId),
      });

      const io = req.app.get('io');
      if (!io) return;
      for (const memberId of result.recipientIds) {
        io.to(`user_${memberId}`).emit('message_reaction', {
          chatId: result.chatId,
          messageId,
          reactions: visibleTo(memberId),
        });
      }
    } catch (err) {
      fail(res, err, 'Failed to react to message', 'setReaction');
    }
  },

  /** "Message Info": who has received / read one of MY messages. */
  async getMessageReceipts(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const rows = await receipts.getMessageReceipts(Number(req.params.messageId), req.user.id);
      res.json(rows);
    } catch (err) {
      fail(res, err, 'Failed to load message info', 'getMessageReceipts');
    }
  },

  async createGroupChat(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const { name, memberIds, avatar } = req.body ?? {};

      if (typeof name !== 'string' || !name.trim()) {
        return res.status(400).json({ error: 'Group name is required' });
      }
      if (name.trim().length > MAX_GROUP_NAME_LENGTH) {
        return res.status(400).json({ error: `Group name must be under ${MAX_GROUP_NAME_LENGTH} characters` });
      }
      if (!Array.isArray(memberIds) || memberIds.length === 0) {
        return res.status(400).json({ error: 'Select at least one member' });
      }
      if (memberIds.length > MAX_GROUP_MEMBERS) {
        return res.status(400).json({ error: `A group can have at most ${MAX_GROUP_MEMBERS} members` });
      }
      const ids = memberIds.map(parseId);
      if (ids.some((id) => id === null)) {
        return res.status(400).json({ error: 'memberIds must be positive integers' });
      }
      // Only our own uploads may be used as an avatar — never an arbitrary URL
      // that every member's device would then be made to fetch.
      const cleanAvatar =
        typeof avatar === 'string' && /^https:\/\/res\.cloudinary\.com\//.test(avatar) ? avatar : null;

      const chat = await chatService.createGroupChat(req.user.id, name.trim(), ids as number[], cleanAvatar);
      res.json({ id: chat.id });
    } catch (err) {
      fail(res, err, 'Failed to create group', 'createGroupChat');
    }
  },

  async addMember(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const userId = parseId(req.body?.userId);
      if (!userId) {
        return res.status(400).json({ error: 'Valid userId required' });
      }
      const result = await chatService.addMember(chatId, req.user.id, userId);
      res.json(result);
    } catch (err) {
      fail(res, err, 'Failed to add member', 'addMember');
    }
  },

  async removeMember(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const userId = Number(req.params.userId);
      const removed = await chatService.removeMember(chatId, req.user.id, userId);

      // Tell the removed user's devices to drop the chat from their list
      const io = req.app.get('io');
      if (removed && io) {
        io.to(`user_${userId}`).emit('group_deleted', { chatId });
      }

      res.json({ success: true });
    } catch (err) {
      fail(res, err, 'Failed to remove member', 'removeMember');
    }
  },

  async updateGroupInfo(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);

      let name: string | undefined;
      if (req.body?.name !== undefined) {
        if (typeof req.body.name !== 'string' || !req.body.name.trim()) {
          return res.status(400).json({ error: 'Group name cannot be empty' });
        }
        name = req.body.name.trim();
        if (name!.length > MAX_GROUP_NAME_LENGTH) {
          return res.status(400).json({ error: `Group name must be under ${MAX_GROUP_NAME_LENGTH} characters` });
        }
      }

      // Verify access before spending a Cloudinary upload on the request
      if (!(await chatService.isMember(chatId, req.user.id))) {
        return res.status(404).json({ error: 'Group not found' });
      }

      // The avatar can only be set by uploading a file, never by passing a URL
      let avatarUrl: string | undefined;
      if (req.file) {
        avatarUrl = await chatService.uploadGroupAvatar(
          req.file.buffer,
          req.file.originalname,
          req.file.mimetype
        );
      }

      const result = await chatService.updateGroupInfo(chatId, req.user.id, name, avatarUrl);
      res.json(result);
    } catch (err) {
      fail(res, err, 'Failed to update group', 'updateGroupInfo');
    }
  },

  async deleteMessage(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const messageId = Number(req.params.messageId);
      const senderId = req.user.id;

      const deleted = await chatService.deleteMessage(messageId, senderId);
      if (!deleted) {
        return res.status(404).json({ error: 'Message not found or not authorized' });
      }

      // Use the chat the message REALLY belonged to, not the id from the URL,
      // so a crafted URL can't push delete events into an unrelated chat.
      const chatId = Number(deleted.chatId);
      const io = req.app.get('io');
      await broadcastToChatMembers(io, chatId, senderId, 'message_deleted', { messageId, chatId });

      res.json({ success: true, messageId, chatId });
    } catch (err) {
      fail(res, err, 'Failed to delete message', 'deleteMessage');
    }
  },

  async deleteChat(req: AuthRequest, res: Response) {
    try {
      if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
      const chatId = Number(req.params.chatId);
      const { notifyUserIds } = await chatService.deleteChat(chatId, req.user.id);

      const io = req.app.get('io');
      if (io) {
        for (const memberId of notifyUserIds) {
          io.to(`user_${memberId}`).emit('group_deleted', { chatId });
        }
      }

      res.json({ success: true });
    } catch (err) {
      fail(res, err, 'Failed to delete chat', 'deleteChat');
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
    } catch (err) {
      fail(res, err, 'Failed to delete group', 'deleteGroup');
    }
  },
};
