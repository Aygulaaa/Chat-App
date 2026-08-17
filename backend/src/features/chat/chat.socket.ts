import { Server, Socket } from "socket.io";
import { chatService } from "./chat.service";
import { userService } from "../users/user.service";
import { settingsService } from "../settings/settings.service";
import db from "../../db";
import { messaging } from "../../config/firebase";

interface SendMessagePayload { chatId: number; text: string; }
interface MessageReceivedPayload { messageId: number; }
interface ReadMessagesPayload { chatId: number; }

export interface AuthSocket extends Socket {
  user?: { id: number };
}

const onlineUsers = new Map<number, Set<string>>();

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

      io.emit("user_status", { userId, status: "online" });

      socket.emit("initial_online_users", Array.from(onlineUsers.keys()));

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
        socket.emit("chat_read", { chatId, });
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

          // Get sender info for notification title
          const senderResult = await db.query(
            `SELECT name, username FROM users WHERE id = $1`,
            [socket.user.id]
          );
          const senderName = senderResult.rows[0]?.name || senderResult.rows[0]?.username || "New Message";

          // Fetch chat members along with their fcm_token
          const membersResult = await db.query(
            `SELECT cm.user_id, u.fcm_token 
             FROM chat_members cm 
             JOIN users u ON u.id = cm.user_id 
             WHERE cm.chat_id = $1`,
            [chatId]
          );

          // Get all socket instances currently connected to check active chat status
          const sockets = await io.in(`user_`).fetchSockets();

          for (const member of membersResult.rows) {
            const memberId = member.user_id;

            // Emit via WebSocket to all connected devices of the user
            io.to(`user_${memberId}`).emit("message", message);

            // Skip sending push notification to the sender
            if (memberId === socket.user.id) continue;

            // Check if the recipient is currently active in THIS specific chat
            const recipientSockets = await io.in(`user_${memberId}`).fetchSockets();
            const isInsideActiveChat = recipientSockets.some(
              (s) => s.data.activeChatId === chatId
            );

            // Send Push Notification if recipient is not actively viewing the chat & has an FCM token
            if (!isInsideActiveChat && member.fcm_token) {
              sendChatPushNotification({
                fcmToken: member.fcm_token,
                title: senderName,
                body: text.trim(),
                chatId,
                senderId: socket.user.id,
              });
            }
          }

        } catch (e) {
          console.error("send_message FAILED:", e);
        }
      });

      socket.on("request_online_users", () => {
        socket.emit("initial_online_users", Array.from(onlineUsers.keys()));
      });

      socket.on("typing", ({ chatId, userId }: { chatId: number, userId: number }) => {
        if (!socket.user || !chatId) return;
        socket.to(`chat_${chatId}`).emit("user_typing", { chatId, userId, isTyping: true });
      });

      socket.on("stop_typing", ({ chatId, userId }: { chatId: number, userId: number }) => {
        if (!socket.user || !chatId) return;
        socket.to(`chat_${chatId}`).emit("user_typing", { chatId, userId, isTyping: false });
      });


      socket.on("message_received", async ({ messageId }: MessageReceivedPayload) => {
        try {
          if (!messageId) return;
          console.log(`message_received for messageId ${messageId} from user ${socket.user?.id}`);
          
          const msgResult = await db.query(
            `SELECT sender_id FROM messages WHERE id = $1`, [messageId]
          );
          if (msgResult.rowCount === 0) return;
          const msg = msgResult.rows[0];
          
          if (msg.sender_id === socket.user?.id) {
             return;
          }

          const result = await db.query(
            `UPDATE messages SET delivered_at = COALESCE(delivered_at, NOW()) WHERE id = $1 RETURNING *`,
            [messageId]
          );
          const message = result.rows[0];
          if (!message) return;
          console.log(`Message ${messageId} marked as delivered in DB`);

          io.to(`user_${message.sender_id}`).emit("messages_delivered", {
            chatId: message.chat_id,
            messageIds: [messageId],
          });
        } catch (error) {
          console.error("message_received error:", error);
        }
      });


      async function handleMarkAsRead(
        chatId: number,
        currentUserId: number
      ) {
        const readMessages =
          await chatService.markMessagesRead(
            chatId,
            currentUserId
          );

        if (!readMessages.length) return;

        // READER SETTINGS
        const currentUserSettings =
          await settingsService.getSettings(
            currentUserId
          );

        // Reader disabled receipts
        if (currentUserSettings.hideReadReceipts) {
          return;
        }
        io.to(`chat_${chatId}`).emit("chat_read", {
          chatId,
          readBy: currentUserId,
          messageIds: readMessages.map((m: any) => m.id)
        });
        
        const senderIds = [
          ...new Set(
            readMessages.map(
              (m: any) =>
                m.senderId ?? m.sender_id
            )
          ),
        ] as number[];

        for (const senderId of senderIds) {
          if (senderId === currentUserId)
            continue;


          const senderSettings =
            await settingsService.getSettings(
              senderId
            );

          if (senderSettings.hideReadReceipts) {
            continue;
          }

          io.to(`user_${senderId}`).emit(
            "messages_read",
            {
              chatId,
              readBy: currentUserId,
              messageIds: readMessages
                .filter(
                  (m: any) =>
                    (m.senderId ??
                      m.sender_id) === senderId
                )
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

                io.emit("user_status", {
                  userId,
                  status: "offline",
                  lastSeen: settings.hideLastSeen ? null : new Date().toISOString(),
                  lastSeenFuzzy: settings.hideLastSeen ? 'recently' : null,
                });
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

async function sendChatPushNotification({ fcmToken, title, body, chatId, senderId }: { fcmToken: string; title: string; body: string; chatId: number; senderId: number; }) {
  try {
    await messaging.send({
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data: {
        chatId: chatId.toString(),
        senderId: senderId.toString(),
        type: 'chat_message'
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'chat_messages',
          priority: 'high',
          sound: 'default'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            contentAvailable: true
          }
        }
      }
    });
    console.log(`Push notification sent to ${fcmToken}`);
  } catch (error) {
    console.error('Error sending push notification:', error);
  }
}
