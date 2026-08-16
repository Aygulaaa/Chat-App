// src/services/notification.service.ts
import { messaging } from '../config/firebase';

interface SendChatPushPayload {
  fcmToken: string;
  title: string;
  body: string;
  chatId: number | string;
  senderId: number | string;
}

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
    console.error('Error sending push notification:', error);
    // If token is invalid/expired, you can clean it up in your DB here
  }
}