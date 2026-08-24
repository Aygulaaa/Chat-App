// controllers/chat.controller.ts
import { Response } from 'express';
import { chatService } from '../chat/chat.service';
import { AuthRequest } from '../../middleware/auth.middleware';
import db from '../../db';
import { sendChatPushNotification } from '../../services/notificationService';

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

            const senderResult = await db.query(
                `SELECT name, username FROM users WHERE id = $1`,
                [senderId]
            );
            const senderName = senderResult.rows[0]?.name || senderResult.rows[0]?.username || 'New Message';

            const io = req.app.get('io');

            const membersResult = await db.query(
                `SELECT cm.user_id, u.fcm_token
                 FROM chat_members cm
                 JOIN users u ON u.id = cm.user_id
                 WHERE cm.chat_id = $1`,
                [chatId]
            );

            for (const member of membersResult.rows) {
                const memberId = Number(member.user_id);

                if (memberId !== senderId) {
                    const blockCheck = await db.query(
                        `SELECT 1 FROM contacts 
                         WHERE ((user_id = $1 AND contact_user_id = $2)
                            OR (user_id = $2 AND contact_user_id = $1))
                           AND status = 'blocked'`,
                        [memberId, senderId]
                    );
                    if (blockCheck.rows.length > 0) continue;
                }

                if (io) {
                    io.to(`user_${memberId}`).emit('message', message);
                }

                if (memberId === senderId) continue;

                // Send push notification only if recipient is not actively viewing this chat
                const recipientSockets = io ? await io.in(`user_${memberId}`).fetchSockets() : [];
                const isInsideActiveChat = recipientSockets.some(
                    (s: any) => s.data.activeChatId === chatId
                );

                if (!isInsideActiveChat && member.fcm_token) {
                    sendChatPushNotification({
                        fcmToken: member.fcm_token,
                        title: senderName,
                        body: text,
                        chatId,
                        senderId,
                    });
                }
            }

            if (!io) {
                console.error('Socket.io instance not found on app settings');
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

            const senderResult = await db.query(
                `SELECT name, username FROM users WHERE id = $1`,
                [senderId]
            );
            const senderName = senderResult.rows[0]?.name || senderResult.rows[0]?.username || 'New Message';

            const io = req.app.get('io');

            const membersResult = await db.query(
                `SELECT cm.user_id, u.fcm_token
                 FROM chat_members cm
                 JOIN users u ON u.id = cm.user_id
                 WHERE cm.chat_id = $1`,
                [chatId]
            );

            for (const member of membersResult.rows) {
                const memberId = Number(member.user_id);

                if (memberId !== senderId) {
                    const blockCheck = await db.query(
                        `SELECT 1 FROM contacts 
                         WHERE ((user_id = $1 AND contact_user_id = $2)
                            OR (user_id = $2 AND contact_user_id = $1))
                           AND status = 'blocked'`,
                        [memberId, senderId]
                    );
                    if (blockCheck.rows.length > 0) continue;
                }

                if (io) {
                    io.to(`user_${memberId}`).emit('message', message);
                }

                if (memberId === senderId) continue;

                // Send push notification only if recipient is not actively viewing this chat
                const recipientSockets = io ? await io.in(`user_${memberId}`).fetchSockets() : [];
                const isInsideActiveChat = recipientSockets.some(
                    (s: any) => s.data.activeChatId === chatId
                );

                if (!isInsideActiveChat && member.fcm_token) {
                    sendChatPushNotification({
                        fcmToken: member.fcm_token,
                        title: senderName,
                        body: req.file.originalname,
                        chatId,
                        senderId,
                    });
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