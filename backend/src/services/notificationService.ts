// src/services/notificationService.ts
import { Server } from 'socket.io';
import db from '../db';
import { messaging } from '../config/firebase';
import { log } from 'console';

interface SendChatPushPayload {
  fcmToken: string;
  title: string;
  body: string;
  chatId: number | string;
  senderId: number | string;
}

export async function sendChatPushNotification(payload: SendChatPushPayload): Promise<void> {
  console.log("🚀 ~ notificationService.ts:15 ~ sendChatPushNotification ~ payload:", payload)

  if (!messaging || !payload.fcmToken) return;

  try {
    await messaging.send({
      token: payload.fcmToken,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        chatId: String(payload.chatId),
        senderId: String(payload.senderId),
        title: String(payload.title),
        body: String(payload.body),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'chat_messages',
          priority: 'max',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });
  } catch (error: any) {
    console.error('FCM send error:', error?.message ?? error);
    // Invalid / expired tokens can be cleaned up here if needed
  }
}

async function isBlocked(userId1: number, userId2: number): Promise<boolean> {
  const result = await db.query(
    `SELECT 1 FROM contacts
     WHERE ((user_id = $1 AND contact_user_id = $2)
        OR  (user_id = $2 AND contact_user_id = $1))
       AND status = 'blocked'`,
    [userId1, userId2]
  );
  return (result.rowCount !== null && result.rowCount > 0) || result.rows.length > 0;
}

/**
 * Send FCM push notifications to all chat members who are NOT actively
 * viewing this chat right now. Works for both socket and REST send flows.
 *
 * @param io         - Socket.io server instance (pass null if unavailable)
 * @param chatId     - The chat the message belongs to
 * @param senderId   - The user who sent the message
 * @param senderName - Display name used as the notification title
 * @param body       - Notification body (message text or file label)
 */
export async function sendPushToMembers(
  io: Server | null,
  chatId: number,
  senderId: number,
  senderName: string,
  body: string,
  messageId?: number
): Promise<void> {
  // Fetch all members with their FCM tokens and notification settings in one query
  const membersResult = await db.query(
    `SELECT cm.user_id, u.fcm_token, COALESCE(us.notifications_enabled, true) AS notifications_enabled
     FROM chat_members cm
     JOIN users u ON u.id = cm.user_id
     LEFT JOIN user_settings us ON us.user_id = cm.user_id
     WHERE cm.chat_id = $1`,
    [chatId]
  );

  for (const member of membersResult.rows) {
    const memberId = Number(member.user_id);

    // Never push to the sender themselves
    if (memberId === senderId) continue;

    // Skip if recipient has notifications disabled in their settings
    if (member.notifications_enabled === false) continue;

    // Skip blocked pairs
    const blocked = await isBlocked(memberId, senderId);
    if (blocked) continue;

    // Skip if the recipient has no FCM token stored
    if (!member.fcm_token) continue;

    // If we have a live socket server, check whether the recipient
    // currently has this chat open — if so, no push needed.
    if (io) {
      const recipientSockets = await io.in(`user_${memberId}`).fetchSockets();
      const isInsideActiveChat = recipientSockets.some(
        (s: any) => s.data.activeChatId != null && Number(s.data.activeChatId) === Number(chatId)
      );
      if (isInsideActiveChat) continue;
    }
    // If io is null (no active socket), the user is definitely outside
    // the app, so we always send the push.
    console.log('socket is not active sendin gpush notifcation:', `${senderName} : ${body}`, member.fcm_token);

    try {
      await sendChatPushNotification({
        fcmToken: member.fcm_token,
        title: senderName,
        body,
        chatId,
        senderId,
      });

      // Mark delivered in db if messageId is provided
      if (messageId) {
        await db.query(
          `UPDATE messages SET delivered_at = COALESCE(delivered_at, NOW()) WHERE id = $1`,
          [messageId]
        );
        if (io) {
          io.to(`user_${senderId}`).emit("messages_delivered", {
            chatId,
            messageIds: [messageId],
          });
        }
      }
    } catch (e) {
      console.error('Error sending push notification for member:', e);
    }
  }
}