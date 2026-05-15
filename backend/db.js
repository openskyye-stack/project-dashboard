import sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import path from 'path';

let db = null;

export async function initDB() {
  if (db) return db;

  db = await open({
    filename: path.join(process.cwd(), 'dashboard.db'),
    driver: sqlite3.Database,
  });

  await db.exec('PRAGMA foreign_keys = ON');

  // NOTE: user_id now comes from authenticated user (JWT token).
  // Schema supports multi-user with data isolation.

  await db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      master_pin_hash TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS projects (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      status TEXT NOT NULL DEFAULT 'not_started',
      date_started TEXT NOT NULL,
      next_action TEXT,
      notes TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS accomplishments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL DEFAULT 1,
      project_id INTEGER NOT NULL,
      entry TEXT NOT NULL,
      date_logged TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS project_tags (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL DEFAULT 1,
      project_id INTEGER NOT NULL,
      tag TEXT NOT NULL,
      FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS project_links (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL DEFAULT 1,
      project_id INTEGER NOT NULL,
      title TEXT,
      url TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS recovery_codes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      code TEXT UNIQUE NOT NULL,
      used BOOLEAN DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      used_at TEXT,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
    CREATE INDEX IF NOT EXISTS idx_projects_user_id ON projects(user_id);
    CREATE INDEX IF NOT EXISTS idx_accomplishments_project_id ON accomplishments(project_id);
    CREATE INDEX IF NOT EXISTS idx_project_tags_project_id ON project_tags(project_id);
    CREATE INDEX IF NOT EXISTS idx_project_links_project_id ON project_links(project_id);
  `);

  return db;
}

export function getDB() {
  if (!db) throw new Error('Database not initialized');
  return db;
}
