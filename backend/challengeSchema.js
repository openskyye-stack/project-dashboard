import { getDB } from './db.js';

// Tables for the 75-day challenge tracker.
//
// Kept in their own module rather than folded into db.js so the challenge
// feature stays separable from the project dashboard it shares a server with.
// Every table carries user_id and every query filters on it, same as projects.
//
// A few columns hold JSON text rather than being normalised into their own
// tables. That is deliberate and limited to values that are always read and
// written as a whole: the frozen rule set for a run, the morning check-in, and
// the per-task progress for a day. Splitting those out would buy joins we never
// need and cost a round trip on every tap of a task card.

export async function initChallengeSchema() {
  const db = getDB();

  await db.exec(`
    CREATE TABLE IF NOT EXISTS challenge_profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL UNIQUE,
      data TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS challenge_runs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      tier TEXT NOT NULL,
      start_date TEXT NOT NULL,
      total_days INTEGER NOT NULL DEFAULT 75,
      is_active INTEGER NOT NULL DEFAULT 1,
      ended_at TEXT,
      end_reason TEXT,
      rule_set TEXT NOT NULL,
      xp INTEGER NOT NULL DEFAULT 0,
      coins INTEGER NOT NULL DEFAULT 0,
      freeze_tokens INTEGER NOT NULL DEFAULT 0,
      rest_days_used INTEGER NOT NULL DEFAULT 0,
      longest_streak INTEGER NOT NULL DEFAULT 0,
      attempt_number INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS challenge_days (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      run_id INTEGER NOT NULL,
      day_number INTEGER NOT NULL,
      date TEXT NOT NULL,
      check_in TEXT,
      scale_factor REAL NOT NULL DEFAULT 1,
      scale_reason TEXT DEFAULT '',
      entries TEXT NOT NULL DEFAULT '{}',
      is_complete INTEGER NOT NULL DEFAULT 0,
      completed_at TEXT,
      used_freeze INTEGER NOT NULL DEFAULT 0,
      miss_acknowledged INTEGER NOT NULL DEFAULT 0,
      photo TEXT,
      reflection TEXT DEFAULT '',
      xp_earned INTEGER NOT NULL DEFAULT 0,
      coins_earned INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(run_id) REFERENCES challenge_runs(id) ON DELETE CASCADE,
      UNIQUE(run_id, day_number)
    );

    CREATE TABLE IF NOT EXISTS challenge_recipes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      data TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS challenge_meals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      slot TEXT NOT NULL,
      recipe_id TEXT NOT NULL,
      recipe_title TEXT NOT NULL,
      servings INTEGER NOT NULL DEFAULT 1,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS challenge_shopping (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      week_start TEXT NOT NULL,
      name TEXT NOT NULL,
      quantity REAL NOT NULL DEFAULT 1,
      unit TEXT DEFAULT '',
      aisle TEXT DEFAULT 'other',
      checked INTEGER NOT NULL DEFAULT 0,
      manual INTEGER NOT NULL DEFAULT 0,
      sources TEXT DEFAULT '[]',
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS challenge_rewards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      detail TEXT DEFAULT '',
      cost INTEGER NOT NULL DEFAULT 50,
      category TEXT NOT NULL DEFAULT 'treat',
      symbol TEXT DEFAULT 'gift',
      is_custom INTEGER NOT NULL DEFAULT 0,
      unlocks_at_day INTEGER,
      times_redeemed INTEGER NOT NULL DEFAULT 0,
      archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS challenge_redemptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      reward_title TEXT NOT NULL,
      cost INTEGER NOT NULL,
      day_number INTEGER NOT NULL DEFAULT 0,
      note TEXT DEFAULT '',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS challenge_achievements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      code TEXT NOT NULL,
      run_id INTEGER,
      unlocked_at TEXT DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(user_id, code),
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_challenge_runs_user ON challenge_runs(user_id, is_active);
    CREATE INDEX IF NOT EXISTS idx_challenge_days_run ON challenge_days(run_id, day_number);
    CREATE INDEX IF NOT EXISTS idx_challenge_meals_user_date ON challenge_meals(user_id, date);
    CREATE INDEX IF NOT EXISTS idx_challenge_shopping_week ON challenge_shopping(user_id, week_start);
    CREATE INDEX IF NOT EXISTS idx_challenge_rewards_user ON challenge_rewards(user_id);
  `);
}
