import { db } from "../../db";

export const createUser = async (username: string, password: string) => {
const client = await db.connect();

try {
  await client.query("BEGIN");

  const userResult = await client.query(
    `INSERT INTO users (username, password)
     VALUES ($1,$2)
     RETURNING id, username`,
    [username, password]
  );

  const user = userResult.rows[0];

  await client.query(
    `INSERT INTO user_settings (user_id)
     VALUES ($1)`,
    [user.id]
  );

  await client.query("COMMIT");

  return user;
} catch (err) {
  await client.query("ROLLBACK");
  throw err;
} finally {
  client.release();
}
};


export const findByUsername = async (username: string) => {
  const result = await db.query(
    `SELECT * FROM users WHERE username = $1`,
    [username]
  );

  return result.rows[0];
};

export const findById = async (id: number) => {
  const result = await db.query(
    `SELECT id, username FROM users WHERE id = $1`,
    [id]
  );

  return result.rows[0];
};