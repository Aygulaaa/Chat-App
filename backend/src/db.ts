import dns from 'dns';
dns.setDefaultResultOrder('ipv4first');

import { Pool, PoolClient } from "pg";
import dotenv from "dotenv";

dotenv.config();

// DEBUG: Print actual value
console.log('DEBUG - DATABASE_URL value:');
console.log(process.env.DATABASE_URL);
console.log('');
const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  console.error('❌ DATABASE_URL is not defined!');
  process.exit(1);
}

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

const connectDB = async () => {
  try {
    const client: PoolClient = await db.connect();
    console.log("✅ PostgreSQL Connected to Supabase via Pooler");
    client.release();
    return true;
  } catch (err: any) {
    console.error("❌ DB ERROR:", err.message);
    console.error("Details:", err);
    return false;
  }
};

connectDB();

export default db;