// src/config/firebase.ts
import { initializeApp, cert, ServiceAccount } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { readFileSync } from 'fs';
import path from 'path';

// Resolve path to the JSON file at root level
const serviceAccountPath = path.resolve(__dirname, '../../firebase-service-account.json');
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf-8')) as ServiceAccount;

initializeApp({
  credential: cert(serviceAccount),
});

// Export the messaging instance for use across your app
export const messaging = getMessaging();