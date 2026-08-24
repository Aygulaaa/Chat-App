// src/services/notification.service.ts
import { messaging } from '../config/firebase';
import db from '../db';

interface SendChatPushPayload {
  fcmToken: string;
  title: string;
  body: string;
  chatId: number | string;
  senderId: number | string;
  /** Optional: recipient user id — used to clear a stale token from the DB */
  recipientId?: number | string;
}

/** Human-readable body for file-type messages */
export function fileNotificationBody(fileType: string | null | undefined): string {
  switch (fileType) {
    case 'image': return '📷 Photo';
    case 'video': return '🎥 Video';
    case 'audio': return '🎵 Voice message';
    case 'pdf':   return '📄 PDF document';
    case 'archive': return '🗜️ Archive file';
    default:       return '📎 File';
  }
}

/**
 * Sends an FCM push notification for a new chat message.
 * Automatically clears the stale token from the database when FCM
 * returns a token-not-registered error, so future lookups skip it.
 */
export async function sendChatPushNotification(payload: SendChatPushPayload) {
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
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'chat_messages',
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
    const invalidTokenCodes = [
      'messaging/registration-token-not-registered',
      'messaging/invalid-registration-token',
      'messaging/invalid-argument',
    ];

    const isInvalidToken =
      invalidTokenCodes.includes(error?.errorInfo?.code) ||
      invalidTokenCodes.includes(error?.code);

    if (isInvalidToken) {
      console.warn(
        `[FCM] Stale token detected for user ${payload.recipientId ?? 'unknown'} — clearing from DB.`
      );
      // Clear the dead token so we stop attempting to deliver to it
      if (payload.recipientId) {
        await db
          .query(`UPDATE users SET fcm_token = NULL WHERE id = $1 AND fcm_token = $2`, [
            payload.recipientId,
            payload.fcmToken,
          ])
          .catch((dbErr) =>
            console.error('[FCM] Failed to clear stale token from DB:', dbErr)
          );
      }
    } else {
      console.error('[FCM] Error sending push notification:', error?.errorInfo ?? error);
    }
  }
}