import { Server, Socket } from "socket.io";
import { chatService } from "./chat.service";
import { chatRepository } from "./chat.repository";
import { userService } from "../users/user.service";
import { settingsService } from "../settings/settings.service";
import db from "../../db";
import { sendPushToMembers } from "../../services/notificationService";
import { MAX_MESSAGE_LENGTH, parseId } from "./chat.controller";

interface SendMessagePayload {
  chatId: number;
  text: string;
  replyToId?: number | null;
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

// In-Memory Presence, Disconnect, & Privacy Caches
const onlineUsers = new Map<number, Set<string>>();
const disconnectTimers = new Map<number, NodeJS.Timeout>();
const userSettingsCache = new Map<number, boolean>(); // Tracks 'hideLastSeen' to prevent DB bottleneck

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
function isHiddenFor(userId: number): boolean {
  return userSettingsCache.get(userId) ?? false;
}

/**
 * Filter list of users currently online for a given viewer, respecting blocked list.
 * hideLastSeen only hides the TIMESTAMP — online presence is always visible.
 */
function getVisibleOnlineUsers(viewerId: number, blockedIds: Set<number>): number[] {
  const filtered: number[] = [];
  for (const id of onlineUsers.keys()) {
    // Always include yourself
    if (id === viewerId) {
      filtered.push(id);
      continue;
    }
    // Skip blocked users
    if (blockedIds.has(id)) continue;
    // Online status is visible regardless of hideLastSeen
    filtered.push(id);
  }
  return filtered;
}

/**
 * Emit an offline presence event to a recipient.
 * hideLastSeen only hides the timestamp, the offline event is always sent.
 */
function emitPresence(
  io: Server,
  recipientId: number,
  subjectUserId: number,
  status: "online" | "offline",
  subjectHidden: boolean
) {
  const viewerHidden = isHiddenFor(recipientId);

  const payload: Record<string, unknown> = { userId: subjectUserId, status };

  if (status === "offline") {
    // Hide the timestamp if either party hides last seen
    const shouldHideTimestamp = subjectHidden || viewerHidden;
    payload.lastSeen = shouldHideTimestamp ? null : new Date().toISOString();
    payload.lastSeenFuzzy = shouldHideTimestamp ? "recently" : null;
  }

  io.to(`user_${recipientId}`).emit("user_status", payload);
}

/**
 * PRIVACY-SAFE TYPING HANDLER
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

      if (disconnectTimers.has(userId)) {
        clearTimeout(disconnectTimers.get(userId));
        disconnectTimers.delete(userId);
      }

      if (!onlineUsers.has(userId)) {
        onlineUsers.set(userId, new Set());
      }
      onlineUsers.get(userId)!.add(socket.id);

      await socket.join(`user_${userId}`);

      // --- EVENT HANDLERS ---
      socket.on("update_settings", (payload: { hideLastSeen?: boolean }) => {
        if (!socket.user || typeof payload?.hideLastSeen !== "boolean") return;
        userSettingsCache.set(socket.user.id, payload.hideLastSeen);
        // Note: the actual persistence (DB write) should already have happened
        // via the REST settings endpoint before the client emits this — this
        // handler only keeps the in-memory presence cache in sync so it doesn't
        // go stale for the rest of the session.
      });
  
      // Every payload below comes straight from the client: it may be null,
      // a string, or have any shape. Never destructure it in the signature —
      // a `null` payload would throw before our try/catch even starts.
      socket.on("join_chat", async (payload: { chatId?: unknown } | null) => {
        try {
          const chatId = parseId(payload?.chatId);
          if (!socket.user || !chatId) return;
          // Only members may mark a chat as "open" (it suppresses their pushes)
          if (!(await chatRepository.isMember(chatId, socket.user.id))) return;
          socket.join(`chat_${chatId}`);
          socket.data.activeChatId = chatId;
        } catch (error) {
          console.error("join_chat error:", error);
        }
      });

      socket.on("leave_chat", (payload: { chatId?: unknown } | null) => {
        const chatId = parseId(payload?.chatId);
        if (chatId) socket.leave(`chat_${chatId}`);
        socket.data.activeChatId = null;
      });

      socket.on("typing", (payload: { chatId?: unknown } | null) => {
        const chatId = parseId(payload?.chatId);
        if (chatId) handleTypingStatus(socket, io, chatId, true);
      });

      socket.on("stop_typing", (payload: { chatId?: unknown } | null) => {
        const chatId = parseId(payload?.chatId);
        if (chatId) handleTypingStatus(socket, io, chatId, false);
      });

      socket.on("send_message", async (data: SendMessagePayload | null) => {
        try {
          const chatId = parseId(data?.chatId);
          const text = typeof data?.text === "string" ? data.text.trim() : "";
          const senderId = Number(socket.user?.id);

          if (!chatId || !text || !senderId) return;
          if (text.length > MAX_MESSAGE_LENGTH) {
            socket.emit("error_message", `Message is too long (max ${MAX_MESSAGE_LENGTH} characters)`);
            return;
          }

          const message = await chatService.sendMessage(chatId, senderId, text, parseId(data?.replyToId));
          if (!message) return;

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

          for (const row of membersResult.rows) {
            const memberId = Number(row.user_id);
            io.to(`user_${memberId}`).emit("message", message);
          }

          sendPushToMembers(io, chatId, senderId, senderName, text, message.id).catch((err) =>
            console.error("Async Push Notification Error:", err)
          );
        } catch (e) {
          console.error("send_message FAILED:", e);
        }
      });
      socket.on("message_received", async (payload: MessageReceivedPayload | null) => {
        try {
          const msgId = parseId(payload?.messageId);
          if (!msgId || !socket.user) return;

          const result = await db.query(
            `UPDATE messages m
       SET delivered_at = COALESCE(m.delivered_at, NOW())
       WHERE m.id = $1 
         AND m.sender_id != $2
         -- 1. Ensure the user acknowledging receipt is actually in the chat
         AND EXISTS (
           SELECT 1 
           FROM chat_members cm 
           WHERE cm.chat_id = m.chat_id 
             AND cm.user_id = $2
         )
         -- 2. Ensure neither user has blocked the other
         AND NOT EXISTS (
           SELECT 1 
           FROM contacts c 
           WHERE (
               (c.user_id = $2 AND c.contact_user_id = m.sender_id) 
               OR (c.user_id = m.sender_id AND c.contact_user_id = $2)
             )
             AND c.status = 'blocked'
         )
       RETURNING m.chat_id, m.sender_id, m.delivered_at`,
            [msgId, socket.user.id]
          );

          if (result.rowCount === 0) return;
          const { chat_id, sender_id, delivered_at } = result.rows[0];

          io.to(`user_${sender_id}`).emit("messages_delivered", {
            chatId: chat_id,
            messageIds: [msgId],
            deliveredAt: delivered_at,
          });
        } catch (error) {
          console.error("message_received error:", error);
        }
      });

      socket.on("read_messages", async (payload: ReadMessagesPayload | null) => {
        try {
          const chatId = parseId(payload?.chatId);
          if (!socket.user || !chatId) return;

          const readerId = socket.user.id;

          // Always record the read in the DB — that's what clears the reader's
          // own unread badge. Privacy only decides whether OTHERS are told.
          const readMessages = await chatService.markMessagesRead(chatId, readerId);
          if (!readMessages || !readMessages.length) return;

          // 1. Reciprocity: a user who hides receipts doesn't send them either
          const readerSettings = await settingsService.getSettings(readerId);
          if (readerSettings.hideReadReceipts) return;

          // 2. One query: non-blocked members who haven't hidden receipts themselves
          const membersResult = await db.query(
            `SELECT cm.user_id 
             FROM chat_members cm
             LEFT JOIN contacts c ON 
               ((c.user_id = $1 AND c.contact_user_id = cm.user_id) 
                OR (c.user_id = cm.user_id AND c.contact_user_id = $1))
               AND c.status = 'blocked'
             LEFT JOIN user_settings us ON us.user_id = cm.user_id
             WHERE cm.chat_id = $2
               AND c.user_id IS NULL
               AND COALESCE(us.hide_read_receipts, false) = false`,
            [readerId, chatId]
          );

          const readMsgIds = readMessages.map((m) => m.id);
          const readAt = readMessages[0]?.readAt ?? new Date();

          for (const row of membersResult.rows) {
            io.to(`user_${Number(row.user_id)}`).emit("chat_read", {
              chatId,
              readBy: readerId,
              messageIds: readMsgIds,
              readAt,
            });
          }
        } catch (error) {
          console.error("read_messages error:", error);
        }
      });

      socket.on("request_online_users", async () => {
        try {
          if (!socket.user) return;
          const currentBlocked = await getBlockedUserIds(socket.user.id);
          const onlineList = getVisibleOnlineUsers(socket.user.id, currentBlocked);
          socket.emit("initial_online_users", onlineList);
        } catch (error) {
          console.error("request_online_users error:", error);
        }
      });

      socket.on("disconnect", () => {
        try {
          if (!userId) return;
          const userConnections = onlineUsers.get(userId);
          if (!userConnections) return;

          userConnections.delete(socket.id);

          if (userConnections.size === 0) {
            const timer = setTimeout(async () => {
             try {
              const currentConnections = onlineUsers.get(userId);
              if (!currentConnections || currentConnections.size === 0) {
                onlineUsers.delete(userId);
                await userService.updateLastSeen(userId);

                const subjectHidden = isHiddenFor(userId);
                const disconnectBlockedIds = await getBlockedUserIds(userId);

                // --- DO NOT BROADCAST OFFLINE STATUS IF THEY ARE HIDDEN ---
                // if (!isHidden) {
                //   for (const [onlineId] of onlineUsers.entries()) {
                //     if (onlineId !== userId && !disconnectBlockedIds.has(onlineId)) {
                //       io.to(`user_${onlineId}`).emit("user_status", {
                //         userId,
                //         status: "offline",
                //         lastSeen: new Date().toISOString(),
                //         lastSeenFuzzy: null,
                //       });
                //     }
                //   }
                // }

                for (const [onlineId] of onlineUsers.entries()) {
                  if (onlineId === userId || disconnectBlockedIds.has(onlineId)) continue;
                  emitPresence(io, onlineId, userId, "offline", subjectHidden);
                }
                userSettingsCache.delete(userId); // Cleanup
              }
             } catch (error) {
              console.error("offline broadcast error:", error);
             } finally {
              disconnectTimers.delete(userId);
             }
            }, 3000);

            disconnectTimers.set(userId, timer);
          }
        } catch (error) {
          console.error("disconnect error:", error);
        }
      });

      // --- ASYNC SETUP ---
      // Runs AFTER every handler above is attached. Socket.IO does not buffer
      // events for handlers registered later, so awaiting the DB first would
      // drop whatever the client emits right after connecting (join_chat on
      // reconnect) and miss a fast disconnect (leaving the user "online").
      // --- FETCH AND CACHE PRIVACY SETTINGS ON CONNECT ---
      const settings = await settingsService.getSettings(userId);
      userSettingsCache.set(userId, settings.hideLastSeen);

      chatRepository.markUndeliveredMessagesForUser(userId, io).catch((err) =>
        console.error("markUndeliveredMessagesForUser error on connect:", err)
      );

      const blockedIds = await getBlockedUserIds(userId);

      // --- BROADCAST ONLINE PRESENCE TO ALL NON-BLOCKED USERS ---
      // Online status is ALWAYS visible regardless of hideLastSeen.
      // hideLastSeen only affects the last seen timestamp shown when offline.
      for (const [onlineId] of onlineUsers.entries()) {
        if (onlineId === userId || blockedIds.has(onlineId)) continue;
        io.to(`user_${onlineId}`).emit("user_status", { userId, status: "online" });
      }

      const initialOnline = getVisibleOnlineUsers(userId, blockedIds);
      socket.emit("initial_online_users", initialOnline);
    } catch (error) {
      // Setup failed half way (usually a DB blip). Drop the socket so the
      // client's auto-reconnect retries with a clean slate instead of
      // sitting on a connection that has no event handlers attached.
      console.error("connection error:", error);
      socket.disconnect(true);
    }
  });
};