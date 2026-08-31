import { Server, Socket } from "socket.io";
import { chatService } from "./chat.service";
import { userService } from "../users/user.service";
import { settingsService } from "../settings/settings.service";
import db from "../../db";
import { sendPushToMembers } from "../../services/notificationService";

interface SendMessagePayload {
  chatId: number;
  text: string;
}

interface MessageReceivedPayload {
  messageId: number;
}

interface ReadMessagesPayload {
  chatId: number;
}

export interface AuthSocket extends Socket {
  user?: { id: number };
}

// In-Memory Presence & Disconnect Caches
const onlineUsers = new Map<number, Set<string>>();
const disconnectTimers = new Map<number, NodeJS.Timeout>();

/**
 * Single-query retrieval of blocked contacts for a given user ID
 */
async function getBlockedUserIds(userId: number): Promise<Set<number>> {
  const result = await db.query(
    `SELECT 
       CASE WHEN user_id = $1 THEN contact_user_id ELSE user_id END AS blocked_id
     FROM contacts
     WHERE (user_id = $1 OR contact_user_id = $1)
       AND status = 'blocked'`,
    [userId]
  );
  return new Set(result.rows.map((r) => Number(r.blocked_id)));
}

/**
 * Filter list of online users against a specific user's blocked contacts
 */
function getVisibleOnlineUsers(userId: number, blockedIds: Set<number>): number[] {
  const filtered: number[] = [];
  for (const id of onlineUsers.keys()) {
    if (id === userId || !blockedIds.has(id)) {
      filtered.push(id);
    }
  }
  return filtered;
}

/**
 * PRIVACY-SAFE TYPING HANDLER:
 * Fetches group chat members and excludes any user who has a mutual block relationship 
 * with the sender, ensuring typing events are never leaked to blocked users.
 */
async function handleTypingStatus(
  socket: AuthSocket,
  io: Server,
  chatId: number,
  isTyping: boolean
) {
  const currentUserId = socket.user?.id;
  if (!currentUserId || !chatId) return;

  try {
    const result = await db.query(
      `SELECT cm.user_id 
       FROM chat_members cm
       LEFT JOIN contacts c ON 
         ((c.user_id = $1 AND c.contact_user_id = cm.user_id) 
          OR (c.user_id = cm.user_id AND c.contact_user_id = $1))
         AND c.status = 'blocked'
       WHERE cm.chat_id = $2 
         AND cm.user_id != $1 
         AND c.user_id IS NULL`,
      [currentUserId, chatId]
    );

    for (const row of result.rows) {
      io.to(`user_${row.user_id}`).emit("user_typing", {
        chatId,
        userId: currentUserId,
        isTyping,
      });
    }
  } catch (error) {
    console.error("handleTypingStatus error:", error);
  }
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

      // Clear any pending disconnect timer (reconnection within grace period)
      if (disconnectTimers.has(userId)) {
        clearTimeout(disconnectTimers.get(userId));
        disconnectTimers.delete(userId);
      }

      // Track multi-device connections for this user
      if (!onlineUsers.has(userId)) {
        onlineUsers.set(userId, new Set());
      }
      onlineUsers.get(userId)!.add(socket.id);

      // Join individual user room for targeted routing
      await socket.join(`user_${userId}`);

      const blockedIds = await getBlockedUserIds(userId);

      // Broadcast 'online' status ONLY to non-blocked, connected contacts
      for (const [onlineId] of onlineUsers.entries()) {
        if (onlineId !== userId && !blockedIds.has(onlineId)) {
          io.to(`user_${onlineId}`).emit("user_status", { userId, status: "online" });
        }
      }

      // Send initial snapshot of unblocked online contacts to the user
      const initialOnline = getVisibleOnlineUsers(userId, blockedIds);
      socket.emit("initial_online_users", initialOnline);

      // --- EVENT HANDLERS ---

      socket.on("join_chat", ({ chatId }: { chatId: number }) => {
        if (!socket.user || !chatId) return;
        socket.join(`chat_${chatId}`);
        socket.data.activeChatId = chatId;
      });

      socket.on("leave_chat", ({ chatId }: { chatId: number }) => {
        if (!chatId) return;
        socket.leave(`chat_${chatId}`);
        socket.data.activeChatId = null;
      });

      socket.on("typing", ({ chatId }: { chatId: number }) => {
        handleTypingStatus(socket, io, chatId, true);
      });

      socket.on("stop_typing", ({ chatId }: { chatId: number }) => {
        handleTypingStatus(socket, io, chatId, false);
      });

      socket.on("send_message", async (data: SendMessagePayload) => {
        try {
          const { chatId, text } = data;
          const senderId = Number(socket.user?.id);

          if (!chatId || !text?.trim() || !senderId) return;

          // 1. Persist message atomically
          const message = await chatService.sendMessage(chatId, senderId, text.trim());
          if (!message) return;

          // 2. Fetch sender name and unblocked chat members in ONE SQL query
          const membersResult = await db.query(
            `SELECT 
               cm.user_id,
               u.username AS sender_name
             FROM chat_members cm
             LEFT JOIN users u ON u.id = $2
             LEFT JOIN contacts c ON 
               ((c.user_id = $2 AND c.contact_user_id = cm.user_id) 
                OR (c.user_id = cm.user_id AND c.contact_user_id = $2))
               AND c.status = 'blocked'
             WHERE cm.chat_id = $1 
               AND (cm.user_id = $2 OR c.user_id IS NULL)`,
            [chatId, senderId]
          );

          if (!membersResult.rows.length) return;
          const senderName = membersResult.rows[0]?.sender_name || "New Message";

          // 3. Emit message to unblocked members' targeted rooms
          for (const row of membersResult.rows) {
            const memberId = Number(row.user_id);
            io.to(`user_${memberId}`).emit("message", message);
          }

          // 4. Trigger background FCM notifications asynchronously
          sendPushToMembers(io, chatId, senderId, senderName, text.trim(), message.id).catch((err) =>
            console.error("Async Push Notification Error:", err)
          );
        } catch (e) {
          console.error("send_message FAILED:", e);
        }
      });

      socket.on("message_received", async ({ messageId }: MessageReceivedPayload) => {
        try {
          const msgId = Number(messageId);
          if (!msgId || !socket.user) return;

          // Atomically mark delivered if not blocked
          const result = await db.query(
            `UPDATE messages m
             SET delivered_at = COALESCE(m.delivered_at, NOW())
             FROM chat_members cm
             LEFT JOIN contacts c ON 
               ((c.user_id = $2 AND c.contact_user_id = m.sender_id) 
                OR (c.user_id = m.sender_id AND c.contact_user_id = $2))
               AND c.status = 'blocked'
             WHERE m.id = $1 
               AND cm.chat_id = m.chat_id 
               AND cm.user_id = $2
               AND m.sender_id != $2
               AND c.user_id IS NULL
             RETURNING m.chat_id, m.sender_id`,
            [msgId, socket.user.id]
          );

          if (result.rowCount === 0) return;
          const { chat_id, sender_id } = result.rows[0];

          io.to(`user_${sender_id}`).emit("messages_delivered", {
            chatId: chat_id,
            messageIds: [msgId],
          });
        } catch (error) {
          console.error("message_received error:", error);
        }
      });

      socket.on("read_messages", async ({ chatId }: ReadMessagesPayload) => {
        if (!socket.user || !chatId) return;
        await handleMarkAsRead(chatId, socket.user.id);
      });

      socket.on("request_online_users", async () => {
        if (!socket.user) return;
        const currentBlocked = await getBlockedUserIds(socket.user.id);
        const onlineList = getVisibleOnlineUsers(socket.user.id, currentBlocked);
        socket.emit("initial_online_users", onlineList);
      });

      async function handleMarkAsRead(chatId: number, currentUserId: number) {
        const readMessages = await chatService.markMessagesRead(chatId, currentUserId);
        if (!readMessages || !readMessages.length) return;

        const currentUserSettings = await settingsService.getSettings(currentUserId);
        if (currentUserSettings.hideReadReceipts) return;

        // Broadcast read receipt to unblocked chat members
        const membersResult = await db.query(
          `SELECT cm.user_id 
           FROM chat_members cm
           LEFT JOIN contacts c ON 
             ((c.user_id = $1 AND c.contact_user_id = cm.user_id) 
              OR (c.user_id = cm.user_id AND c.contact_user_id = $1))
             AND c.status = 'blocked'
           WHERE cm.chat_id = $2 AND c.user_id IS NULL`,
          [currentUserId, chatId]
        );

        const readMsgIds = readMessages.map((m) => m.id);

        for (const row of membersResult.rows) {
          io.to(`user_${row.user_id}`).emit("chat_read", {
            chatId,
            readBy: currentUserId,
            messageIds: readMsgIds,
          });
        }
      }

      socket.on("disconnect", () => {
        try {
          if (!userId) return;
          const userConnections = onlineUsers.get(userId);
          if (!userConnections) return;

          userConnections.delete(socket.id);

          // Grace period (3s) before marking user offline to handle brief network switching
          if (userConnections.size === 0) {
            const timer = setTimeout(async () => {
              const currentConnections = onlineUsers.get(userId);
              if (!currentConnections || currentConnections.size === 0) {
                onlineUsers.delete(userId);
                await userService.updateLastSeen(userId);
                const settings = await settingsService.getSettings(userId);

                const disconnectBlockedIds = await getBlockedUserIds(userId);

                for (const [onlineId] of onlineUsers.entries()) {
                  if (onlineId !== userId && !disconnectBlockedIds.has(onlineId)) {
                    io.to(`user_${onlineId}`).emit("user_status", {
                      userId,
                      status: "offline",
                      lastSeen: settings.hideLastSeen ? null : new Date().toISOString(),
                      lastSeenFuzzy: settings.hideLastSeen ? "recently" : null,
                    });
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