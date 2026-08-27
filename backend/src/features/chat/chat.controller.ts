// controllers/chat.controller.ts
import { Response } from 'express';
import { chatService } from '../chat/chat.service';
import { AuthRequest } from '../../middleware/auth.middleware';
import db from '../../db';
import { sendPushToMembers } from '../../services/notificationService';

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
            const userId = req.user!.id;
            const messages = await chatService.getMessages(chatId, userId);
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

            // Socket emit to all online members
            const io = req.app.get('io');
            if (io) {
                const membersResult = await db.query(
                    `SELECT user_id FROM chat_members WHERE chat_id = $1`,
                    [chatId]
                );
                for (const member of membersResult.rows) {
                    if (member.user_id !== senderId) {
                        const blockCheck = await db.query(
                            `SELECT 1 FROM contacts 
                             WHERE ((user_id = $1 AND contact_user_id = $2)
                                OR (user_id = $2 AND contact_user_id = $1))
                               AND status = 'blocked'`,
                            [member.user_id, senderId]
                        );
                        if (blockCheck.rows.length > 0) continue;
                    }
                    io.to(`user_${member.user_id}`).emit('message', message);
                }
            } else {
                console.error('Socket.io instance not found on app settings');
            }

            // FCM push — send to offline/backgrounded members not viewing this chat
            const senderResult = await db.query(
                `SELECT username FROM users WHERE id = $1`,
                [senderId]
            );
            console.log('sender result while sending message ', senderResult);
            
            const senderName =
                senderResult.rows[0]?.username ||
                'New Message';
            await sendPushToMembers(io ?? null, chatId, senderId, senderName, text);

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

            // Socket emit to all online members
            const io = req.app.get('io');
            if (io) {
                const membersResult = await db.query(
                    `SELECT user_id FROM chat_members WHERE chat_id = $1`,
                    [chatId]
                );
                for (const member of membersResult.rows) {
                    if (member.user_id !== senderId) {
                        const blockCheck = await db.query(
                            `SELECT 1 FROM contacts 
                             WHERE ((user_id = $1 AND contact_user_id = $2)
                                OR (user_id = $2 AND contact_user_id = $1))
                               AND status = 'blocked'`,
                            [member.user_id, senderId]
                        );
                        if (blockCheck.rows.length > 0) continue;
                    }
                    io.to(`user_${member.user_id}`).emit('message', message);
                }
            }

            // FCM push — send to offline/backgrounded members not viewing this chat
            const senderResult = await db.query(
                `SELECT name, username FROM users WHERE id = $1`,
                [senderId]
            );
            const senderName =
                senderResult.rows[0]?.name ||
                senderResult.rows[0]?.username ||
                'New Message';
            // Use original filename as notification body for file messages
            const notifBody = req.file.originalname;
            await sendPushToMembers(io ?? null, chatId, senderId, senderName, notifBody);

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

    async deleteMessage(req: AuthRequest, res: Response) {
        try {
            const chatId = Number(req.params.chatId);
            const messageId = Number(req.params.messageId);
            const senderId = req.user!.id;

            const deleted = await chatService.deleteMessage(messageId, senderId);
            if (!deleted) {
                return res.status(404).json({ error: 'Message not found or not authorised' });
            }

            // Broadcast deletion to all online chat members
            const io = req.app.get('io');
            if (io) {
                const membersResult = await db.query(
                    `SELECT user_id FROM chat_members WHERE chat_id = $1`,
                    [chatId]
                );
                for (const member of membersResult.rows) {
                    io.to(`user_${member.user_id}`).emit('message_deleted', { messageId, chatId });
                }
            }

            res.json({ success: true, messageId, chatId });
        } catch (err) {
            res.status(500).json({ error: 'Failed to delete message' });
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

    async deleteGroup(req: AuthRequest, res: Response) {
        try {
            const chatId = Number(req.params.chatId);
            const requesterId = req.user!.id;

            const { memberIds } = await chatService.deleteGroup(chatId, requesterId);

            // Notify all former members via socket in real-time
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
} 