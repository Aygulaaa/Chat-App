import { Pool } from "pg";
import dotenv from "dotenv";

dotenv.config();

export const db = new Pool({
  connectionString: process.env.DATABASE_URL,
  keepAlive: true,
  idleTimeoutMillis: 30000,
  ssl: {
    rejectUnauthorized: false
  }
});

db.on("error", (err) => {
  console.error("Unexpected DB error:", err.message);
});

db.connect()
  .then(() => console.log("📦 PostgreSQL Connected"))
  .catch(err => console.error("❌ DB ERROR:", err));

export default db;