import db from '../db/index.js';

const insertStmt = db.prepare(`
  INSERT INTO users (userId, passwordHash, displayName, email, createdAt)
  VALUES (@userId, @passwordHash, @displayName, @email, @createdAt)
`);

const findByUserIdStmt = db.prepare(`
  SELECT id, userId, passwordHash, displayName, email, createdAt
  FROM users
  WHERE userId = ?
`);

export function findByUserId(userId) {
  return findByUserIdStmt.get(userId);
}

export function createUser({ userId, passwordHash, displayName, email, createdAt }) {
  const info = insertStmt.run({
    userId,
    passwordHash,
    displayName: displayName ?? null,
    email: email ?? null,
    createdAt,
  });
  return {
    id: info.lastInsertRowid,
    userId,
    passwordHash,
    displayName,
    email,
    createdAt,
  };
}

