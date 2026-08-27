import { Server, Socket } from "socket.io";
import { chatService } from "./chat.service";
import { userService } from "../users/user.service";
import { settingsService } from "../settings/settings.service";
import db from "../../db";
import { messaging } from "../../config/firebase";
import { sendPushToMembers } from "../../services/notificationService";

interface SendMessagePayload { chatId: number; text: string; }
interface MessageReceivedPayload { messageId: number; }
interface ReadMessagesPayload { chatId: number; }

export interface AuthSocket extends Socket {
  user?: { id: number };
}

const onlineUsers = new Map<number, Set<string>>();

async function isBlocked(userId1: number, userId2: number): Promise<boolean> {
  const result = await db.query(
    `SELECT 1 FROM contacts 
     WHERE ((user_id = $1 AND contact_user_id = $2)
        OR (user_id = $2 AND contact_user_id = $1))
       AND status = 'blocked'`,
    [userId1, userId2]
  );
  return (result.rowCount !== null && result.rowCount > 0) || (result.rows.length > 0);
}

export const chatSocket = (io: Server) => {
  io.on("connection", async (socket: AuthSocket) => {
    try {
      const userId = socket.user?.id;
      if (!userId) {
        socket.disconnect();
        return;
      }

      socket.data.user = socket.user;

      if (!onlineUsers.has(userId)) {
        onlineUsers.set(userId, new Set());
      }
      onlineUsers.get(userId)!.add(socket.id);

      await socket.join(`user_${userId}`);

      const allSockets = await io.fetchSockets();
      for (const s of allSockets) {
        if (s.data.user?.id && s.data.user.id !== userId) {
          const blocked = await isBlocked(userId, s.data.user.id);
          if (!blocked) {
            s.emit("user_status", { userId, status: "online" });
          }
        }
      }

      const filteredOnline = [];
      for (const id of Array.from(onlineUsers.keys())) {
        if (id === userId) {
          filteredOnline.push(id);
          continue;
        }
        const blocked = await isBlocked(userId, id);
        if (!blocked) {
          filteredOnline.push(id);
        }
      }
      socket.emit("initial_online_users", filteredOnline);

      socket.on("join_chat", async ({ chatId }: { chatId: number }) => {
        try {
          if (!socket.user) return;
          const room = `chat_${chatId}`;
          socket.join(room);
          socket.data.activeChatId = chatId;
          console.log(`User ${socket.user.id} joined room chat_${chatId}`);
        } catch (error) {
          console.error("join_chat error:", error);
        }
      });

      socket.on("leave_chat", ({ chatId }: { chatId: number }) => {
        socket.leave(`chat_${chatId}`);
        socket.data.activeChatId = null;
        console.log(`User ${socket.user?.id} left room chat_${chatId}`);
      });

      socket.on("read_messages", async ({ chatId }: ReadMessagesPayload) => {
        if (!socket.user) return;
        await handleMarkAsRead(chatId, socket.user.id);
      });

      socket.on("send_message", async (data) => {
        try {
          console.log("SEND:", data);

          const { chatId, text } = data;

          if (!chatId || !text?.trim() || !socket.user) {
            console.log("INVALID MESSAGE");
            return;
          }

          const message = await chatService.sendMessage(
            chatId,
            socket.user.id,
            text.trim()
          );

          console.log("MESSAGE CREATED:", message);

          // 1. Resolve sender display name
          const senderResult = await db.query(
            `SELECT name, username FROM users WHERE id = $1`,
            [socket.user.id]
          );
          const senderName =
            senderResult.rows[0]?.name ||
            senderResult.rows[0]?.username ||
            'New Message';

          // 2. Fetch members for socket emit (block check included)
          const membersResult = await db.query(
            `SELECT cm.user_id
             FROM chat_members cm
             WHERE cm.chat_id = $1`,
            [chatId]
          );

          for (const member of membersResult.rows) {
            const memberId = Number(member.user_id);

            if (memberId !== socket.user.id) {
              const blocked = await isBlocked(memberId, socket.user.id);
              if (blocked) continue;
            }

            io.to(`user_${memberId}`).emit('message', message);
            io.to(`user_${memberId}`).emit('notification', {
              title: senderName,
              body: text.trim(),
              chatId,
              senderId: socket.user.id,
            });
          }

          // 3. FCM push — handled by shared helper (checks blocks, active chat, token)
          await sendPushToMembers(io, chatId, socket.user.id, senderName, text.trim());

        } catch (e) {
          console.error("send_message FAILED:", e);
        }
      });

      socket.on("request_online_users", async () => {
        if (!socket.user) return;
        const filteredOnline = [];
        for (const id of Array.from(onlineUsers.keys())) {
          if (id === socket.user.id) {
            filteredOnline.push(id);
            continue;
          }
          const blocked = await isBlocked(socket.user.id, id);
          if (!blocked) {
            filteredOnline.push(id);
          }
        }
        socket.emit("initial_online_users", filteredOnline);
      });

      socket.on("typing", async ({ chatId, userId }: { chatId: number, userId: number }) => {
        if (!socket.user || !chatId) return;
        const membersResult = await db.query(`SELECT user_id FROM chat_members WHERE chat_id = $1`, [chatId]);
        for (const member of membersResult.rows) {
          const memberId = Number(member.user_id);
          if (memberId !== socket.user.id) {
            const blocked = await isBlocked(memberId, socket.user.id);
            if (!blocked) {
              io.to(`user_${memberId}`).emit("user_typing", { chatId, userId, isTyping: true });
            }
          }
        }
      });

      socket.on("stop_typing", async ({ chatId, userId }: { chatId: number, userId: number }) => {
        if (!socket.user || !chatId) return;
        const membersResult = await db.query(`SELECT user_id FROM chat_members WHERE chat_id = $1`, [chatId]);
        for (const member of membersResult.rows) {
          const memberId = Number(member.user_id);
          if (memberId !== socket.user.id) {
            const blocked = await isBlocked(memberId, socket.user.id);
            if (!blocked) {
              io.to(`user_${memberId}`).emit("user_typing", { chatId, userId, isTyping: false });
            }
          }
        }
      });

      socket.on("message_received", async ({ messageId }: MessageReceivedPayload) => {
        try {
          const msgId = Number(messageId);
          if (!msgId) return;
          console.log(`message_received for messageId ${msgId} from user ${socket.user?.id}`);
          
          const msgResult = await db.query(
            `SELECT sender_id, chat_id FROM messages WHERE id = $1`, [msgId]
          );
          if (msgResult.rowCount === 0) return;
          const msg = msgResult.rows[0];
          
          if (msg.sender_id === socket.user?.id) {
             return;
          }

          const result = await db.query(
            `UPDATE messages SET delivered_at = COALESCE(delivered_at, NOW()) WHERE id = $1 RETURNING *`,
            [msgId]
          );
          const message = result.rows[0];
          if (!message) return;
          console.log(`Message ${msgId} marked as delivered in DB`);

          const blocked = await isBlocked(socket.user!.id, message.sender_id);
          if (!blocked) {
            io.to(`user_${message.sender_id}`).emit("messages_delivered", {
              chatId: message.chat_id,
              messageIds: [msgId],
            });
          }
        } catch (error) {
          console.error("message_received error:", error);
        }
      });

      async function handleMarkAsRead(chatId: number, currentUserId: number) {
        const readMessages = await chatService.markMessagesRead(chatId, currentUserId);
        if (!readMessages.length) return;

        const currentUserSettings = await settingsService.getSettings(currentUserId);
        if (currentUserSettings.hideReadReceipts) {
          return;
        }

        const membersResult = await db.query(`SELECT user_id FROM chat_members WHERE chat_id = $1`, [chatId]);
        for (const member of membersResult.rows) {
          const memberId = Number(member.user_id);
          const blocked = await isBlocked(currentUserId, memberId);
          if (!blocked) {
            io.to(`user_${memberId}`).emit("chat_read", {
              chatId,
              readBy: currentUserId,
              messageIds: readMessages.map((m: any) => m.id)
            });
          }
        }
        
        const senderIds = [...new Set(readMessages.map((m: any) => m.senderId ?? m.sender_id))] as number[];

        for (const senderId of senderIds) {
          if (senderId === currentUserId) continue;
          
          const blocked = await isBlocked(currentUserId, senderId);
          if (blocked) continue;

          const senderSettings = await settingsService.getSettings(senderId);
          if (senderSettings.hideReadReceipts) continue;

          io.to(`user_${senderId}`).emit(
            "messages_read",
            {
              chatId,
              readBy: currentUserId,
              messageIds: readMessages
                .filter((m: any) => (m.senderId ?? m.sender_id) === senderId)
                .map((m: any) => m.id),
            }
          );
        }
      }

      const disconnectTimers = new Map<number, NodeJS.Timeout>();
      socket.on("disconnect", async () => {
        try {
          if (!userId) return;
          const userConnections = onlineUsers.get(userId);
          if (!userConnections) return;

          userConnections.delete(socket.id);

          if (userConnections.size === 0) {
            const timer = setTimeout(async () => {
              const currentConnections = onlineUsers.get(userId);
              if (!currentConnections || currentConnections.size === 0) {
                onlineUsers.delete(userId);
                await userService.updateLastSeen(userId);
                const settings = await settingsService.getSettings(userId);
                
                const allSockets = await io.fetchSockets();
                for (const s of allSockets) {
                  if (s.data.user?.id && s.data.user.id !== userId) {
                    const blocked = await isBlocked(userId, s.data.user.id);
                    if (!blocked) {
                      s.emit("user_status", {
                        userId,
                        status: "offline",
                        lastSeen: settings.hideLastSeen ? null : new Date().toISOString(),
                        lastSeenFuzzy: settings.hideLastSeen ? 'recently' : null,
                      });
                    }
                  }
                }
              }
              disconnectTimers.delete(userId);
            }, 3000);

            disconnectTimers.set(userId, timer);
          }
        } catch (error) {
          console.error("disconnect error:", error);
        }
      });
    } catch (error) {
      console.error("connection error:", error);
    }
  });
};
