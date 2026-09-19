// src/services/notificationService.ts
import { Server } from 'socket.io';
import db from '../db';
import { messaging } from '../config/firebase';

interface SendChatPushPayload {
  fcmToken: string;
  title: string;
  body: string;
  chatId: number | string;
  senderId: number | string;
}

export async function sendChatPushNotification(payload: SendChatPushPayload): Promise<void> {
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
    if (
      error?.code === 'messaging/invalid-registration-token' ||
      error?.code === 'messaging/registration-token-not-registered'
    ) {
      await db.query('UPDATE users SET fcm_token = NULL WHERE fcm_token = $1', [payload.fcmToken]);
      console.log('Cleaned up an invalid FCM token from the database');
    }
  }
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
  // One query: every pushable member — has a token, notifications on, is not
  // the sender, and has no block with the sender in either direction.
  const membersResult = await db.query(
    `SELECT cm.user_id, u.fcm_token
     FROM chat_members cm
     JOIN users u ON u.id = cm.user_id
     LEFT JOIN user_settings us ON us.user_id = cm.user_id
     WHERE cm.chat_id = $1
       AND cm.user_id != $2
       AND u.fcm_token IS NOT NULL
       AND COALESCE(us.notifications_enabled, true) = true
       AND NOT EXISTS (
         SELECT 1 FROM contacts c
         WHERE ((c.user_id = cm.user_id AND c.contact_user_id = $2)
            OR  (c.user_id = $2 AND c.contact_user_id = cm.user_id))
           AND c.status = 'blocked'
       )`,
    [chatId, senderId]
  );

  // Lock-screen previews shouldn't carry a whole essay
  const preview = body.length > 140 ? `${body.slice(0, 137)}…` : body;

  for (const member of membersResult.rows) {
    const memberId = Number(member.user_id);

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
    try {
      await sendChatPushNotification({
        fcmToken: member.fcm_token,
        title: senderName,
        body: preview,
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