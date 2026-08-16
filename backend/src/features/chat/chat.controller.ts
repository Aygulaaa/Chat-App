// controllers/chat.controller.ts
import { Response } from 'express';
import { chatService } from '../chat/chat.service';
import { AuthRequest } from '../../middleware/auth.middleware';
import db from '../../db';

export const chatController = {
    async getChats(req: AuthRequest, res: Response) {
        try {
            if (!req.user) {
                return res.status(401).json({ error: "Unauthorized" });
            }
            const userId = req.user!.id;
            
            const chats = await chatService.getChats(userId);
            res.json(chats);
        } catch (err) {
            res.status(500).json({ error: 'Failed to fetch chats. Error:', err });
        }
    },

    async getChat(req: AuthRequest, res: Response) {
        try {
            const chatId = Number(req.params.chatId);
            const userId = req.user!.id;
            const chat = await chatService.getChat(chatId, userId);
            res.json(chat);
        } catch (err) {
            res.status(500).json({ error: 'Failed to fetch chat. Error:', err });
        }
    },

    async getMessages(req: AuthRequest, res: Response) {
        try {
            const chatId = Number(req.params.chatId);
            const messages = await chatService.getMessages(chatId);
            res.json(messages);
        } catch (err) {
            res.status(500).json({ error: 'Failed to fetch messages. Error:', err });
        }
    },

    async sendMessage(req: AuthRequest, res: Response) {
        try {
            if (!req.user) {
                return res.status(401).json({ error: "Unauthorized" });
            }
            const chatId = Number(req.params.chatId);
            const senderId = req.user!.id;
            
            const { text } = req.body;

            const message = await chatService.sendMessage(chatId, senderId, text);
            const io = req.app.get('io');
            if (io) {
                const membersResult = await db.query(
                    `SELECT user_id FROM chat_members WHERE chat_id = $1`,
                    [chatId]
                );
                for (const member of membersResult.rows) {
                    io.to(`user_${member.user_id}`).emit('message', message);
                }
            } else {
                console.error("Socket.io instance not found on app settings");
            }
            res.json(message);
        } catch (err) {
            res.status(500).json({ error: 'Failed to send message. Error:', err });
        }
    },

    async createChat(req: AuthRequest, res: Response) {
        try {
            const contactId = Number(req.params.contactId);
            const userId = req.user!.id;
            const chat = await chatService.createChat(userId, contactId);
            res.json(chat);
        } catch (err: any) {
            res.status(400).json({ error: err.message ?? 'Failed to create chat. Error:', err });
        }
    },

    async markMessagesRead(req: AuthRequest, res: Response) {
        try {
            const chatId = Number(req.params.chatId);
            const readerId = req.user!.id;
            const messages = await chatService.markMessagesRead(chatId, readerId);
            res.json(messages);
        } catch (err) {
            res.status(500).json({ error: "Failed to mark messages as read. Error:", err });
        }
    },
    async sendFileMessage(req: AuthRequest, res: Response) {
        try {
            if (!req.file) return res.status(400).json({ error: 'No file provided' });

            const chatId = Number(req.params.chatId);
            const senderId = req.user!.id;

            const message = await chatService.sendFileMessage(
                chatId,
                senderId,
                req.file.buffer,
                req.file.originalname,
                req.file.mimetype,
                req.file.size,
            );

            const io = req.app.get('io');
            if (io) {
                const membersResult = await db.query(
                    `SELECT user_id FROM chat_members WHERE chat_id = $1`,
                    [chatId]
                );
                for (const member of membersResult.rows) {
                    io.to(`user_${member.user_id}`).emit('message', message);
                }
            }

            res.json(message);
        } catch (err) {
            console.error('File upload error:', err);
            res.status(500).json({ error: 'Failed to send file. Error:', err });
        }
    },

    async createGroupChat(req: AuthRequest, res: Response) {
        try {
            const { name, memberIds, avatar } = req.body;
            if (!name || !memberIds?.length) {
                return res.status(400).json({ error: 'Name and members required' });
            }
            const chat = await chatService.createGroupChat(
                req.user!.id, name, memberIds, avatar
            );
            res.json(chat);
        } catch (err: any) {
            res.status(500).json({ error: err.message ?? 'Failed to create group' });
        }
    },

    async addMember(req: AuthRequest, res: Response) {
        try {
            const chatId = Number(req.params.chatId);
            const { userId } = req.body;
            const result = await chatService.addMember(chatId, userId);
            res.json(result);
        } catch (err) {
            res.status(500).json({ error: 'Failed to add member' });
        }
    },

    async removeMember(req: AuthRequest, res: Response) {
        try {
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
            console.error('Group info update error:', err);
            res.status(500).json({ error: 'Failed to update group' });
        }
    },

    async deleteChat(req: AuthRequest, res: Response) {
        try {
            const chatId = Number(req.params.chatId);
            await chatService.deleteChat(chatId);
            res.json({ success: true });
        } catch (err) {
            res.status(500).json({ error: 'Failed to delete chat' });
        }
    },
}