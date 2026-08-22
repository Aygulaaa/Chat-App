import { initializeApp, cert, ServiceAccount } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { readFileSync, existsSync } from 'fs';
import path from 'path';

function getServiceAccount(): ServiceAccount {
  const envVal = process.env.FIREBASE_SERVICE_ACCOUNT;

  if (envVal) {
    let rawEnv = envVal.trim();

    // 1. Strip surrounding quotes if present (handles .env file formatting quirks)
    if (
      (rawEnv.startsWith('"') && rawEnv.endsWith('"')) ||
      (rawEnv.startsWith("'") && rawEnv.endsWith("'"))
    ) {
      rawEnv = rawEnv.slice(1, -1).trim();
    }

    let jsonString = rawEnv;

    // 2. Intelligently determine if it's Base64 or raw JSON
    // Valid JSON starts with '{'. If it doesn't, assume it's Base64 encoded.
    if (!rawEnv.startsWith('{')) {
      try {
        jsonString = Buffer.from(rawEnv, 'base64').toString('utf-8');
      } catch (err) {
        throw new Error(`Failed to decode FIREBASE_SERVICE_ACCOUNT from base64: ${(err as Error).message}`);
      }
    }

    // 3. Parse safely with clear debugging info if it fails
    try {
      return JSON.parse(jsonString) as ServiceAccount;
    } catch (err) {
      console.error('--- FIREBASE CONFIG PARSE ERROR ---');
      console.error('Raw Env Length:', rawEnv.length);
      console.error('Decoded/Cleaned String Preview:', jsonString.slice(0, 100) + '...');
      console.error('-----------------------------------');
      throw new Error(`Invalid JSON in FIREBASE_SERVICE_ACCOUNT: ${(err as Error).message}`);
    }
  }

  // Local fallback to file for development if environment variable isn't set
  const serviceAccountPath = path.resolve(__dirname, '../../firebase-service-account.json');
  if (existsSync(serviceAccountPath)) {
    try {
      const fileContent = readFileSync(serviceAccountPath, 'utf-8');
      return JSON.parse(fileContent) as ServiceAccount;
    } catch (err) {
      throw new Error(`Failed to parse local firebase-service-account.json: ${(err as Error).message}`);
    }
  }

  throw new Error(
    'Firebase service account missing. Set FIREBASE_SERVICE_ACCOUNT environment variable or provide backend/firebase-service-account.json.'
  );
}

initializeApp({
  credential: cert(getServiceAccount()),
});

export const messaging = getMessaging();