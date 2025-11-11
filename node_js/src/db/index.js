import path from 'node:path';
import fs from 'node:fs';
import Database from 'better-sqlite3';

const dataDir = path.resolve('node_js', 'data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

const dbPath = path.join(dataDir, 'auth.db');
const db = new Database(dbPath);

db.pragma('foreign_keys = ON');
db.pragma('journal_mode = WAL');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userId TEXT NOT NULL UNIQUE,
    passwordHash TEXT NOT NULL,
    displayName TEXT,
    email TEXT,
    createdAt TEXT NOT NULL
  );
`);

export default db;

