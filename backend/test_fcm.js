const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp({ projectId: 'demo-test' });
const messaging = getMessaging();

const payload = {
  token: 'fake-token',
  notification: { title: 'test', body: 'test' },
  android: {
    priority: 'high',
    notification: {
      channelId: 'chat_messages',
      priority: 'max',
      sound: 'default'
    }
  }
};

messaging.send(payload, true).catch(err => console.error("Send error:", err.message));
