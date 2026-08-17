import { initializeApp, cert, ServiceAccount } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { readFileSync, existsSync } from 'fs';
import path from 'path';

function getServiceAccount(): ServiceAccount {
  // 1. Production / Render: Check for JSON string in environment variable
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const rawEnv = process.env.FIREBASE_SERVICE_ACCOUNT.trim();
    const jsonString = rawEnv.startsWith('{')
      ? rawEnv
      : Buffer.from(rawEnv, 'base64').toString('utf-8');
    
    return JSON.parse(jsonString) as ServiceAccount;
  }

  // 2. Local Development: Fallback to reading local JSON file
  const serviceAccountPath = path.resolve(__dirname, '../../firebase-service-account.json');
  if (existsSync(serviceAccountPath)) {
    return JSON.parse(readFileSync(serviceAccountPath, 'utf-8')) as ServiceAccount;
  }

  throw new Error(
    'Firebase service account missing. Set FIREBASE_SERVICE_ACCOUNT environment variable on Render or provide backend/firebase-service-account.json locally.'
  );
}

initializeApp({
  credential: cert(getServiceAccount()),
});

export const messaging = getMessaging();