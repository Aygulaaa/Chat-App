import dns from 'dns';
dns.setDefaultResultOrder('ipv4first');

import { Pool, PoolClient } from "pg";
import dotenv from "dotenv";

dotenv.config();

const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  console.error('❌ DATABASE_URL is not defined!');
  process.exit(1);
}

// NOTE: never log DATABASE_URL itself — it contains the database password and
// anything written to stdout ends up in the hosting provider's log storage.
// Check what port it's using (Port 5432 is Session Pooler, 6543 is Transaction Pooler)
if (databaseUrl.includes(':5432')) {
  console.log('✅ Using port 5432 (Session Pooler)');
} else if (databaseUrl.includes(':6543')) {
  console.log('✅ Using port 6543 (Transaction Pooler)');
} else {
  console.warn('⚠️  Port not recognized as standard Supabase pooler port');
}

console.log('🔗 Connecting to Supabase...');

export const db = new Pool({
  connectionString: databaseUrl,
  ssl: { rejectUnauthorized: false },
  max: 5,
  connectionTimeoutMillis: 20000,
  idleTimeoutMillis: 30000,
  statement_timeout: 30000,
} as any);

db.on("error", (err) => {
  console.error("❌ Unexpected DB error:", err.message);
});

/**
 * Columns the code depends on that were added after the initial schema.
 * If one is missing we log exactly which migration to run instead of
 * letting every chat query fail with a cryptic "column does not exist".
 */
const REQUIRED_COLUMNS: Array<{ table: string; column: string; migration: string }> = [
  { table: 'messages', column: 'reply_to_id', migration: 'backend/migrations/001_message_replies.sql' },
  { table: 'message_receipts', column: 'message_id', migration: 'backend/migrations/003_message_receipts.sql' },
  { table: 'chat_members', column: 'last_read_message_id', migration: 'backend/migrations/003_message_receipts.sql' },
];

const verifySchema = async (client: PoolClient) => {
  for (const { table, column, migration } of REQUIRED_COLUMNS) {
    const result = await client.query(
      `SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2`,
      [table, column]
    );
    if (result.rowCount === 0) {
      console.error(
        `❌ SCHEMA OUT OF DATE: column "${table}.${column}" is missing. ` +
        `Run ${migration} in the Supabase SQL editor — chat queries will fail until you do.`
      );
    }
  }
};

const connectDB = async () => {
  try {
    const client: PoolClient = await db.connect();
    console.log("✅ PostgreSQL Connected to Supabase via Pooler");
    try {
      await verifySchema(client);
    } finally {
      client.release();
    }
    return true;
  } catch (err: any) {
    console.error("❌ DB ERROR:", err.message);
    return false;
  }
};

connectDB();

export default db;
