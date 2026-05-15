import express from 'express';
import { getDB } from './db.js';
import { createToken, hashPassword, comparePassword, authMiddleware } from './auth.js';

const router = express.Router();

// SIGNUP with Master PIN
router.post('/signup', async (req, res) => {
  try {
    const db = getDB();
    const { username, password, masterPin } = req.body;

    if (!username || !password || !masterPin) {
      return res.status(400).json({ error: 'Username, password, and master PIN required' });
    }

    if (username.length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 characters' });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    if (!/^\d{4,6}$/.test(masterPin)) {
      return res.status(400).json({ error: 'Master PIN must be 4-6 digits' });
    }

    // Check if user exists
    const existing = await db.get('SELECT id FROM users WHERE username = ?', [username]);
    if (existing) {
      return res.status(400).json({ error: 'Username already taken' });
    }

    // Create user
    const passwordHash = hashPassword(password);
    const masterPinHash = hashPassword(masterPin);
    const result = await db.run(
      'INSERT INTO users (username, password_hash, master_pin_hash) VALUES (?, ?, ?)',
      [username, passwordHash, masterPinHash]
    );

    const token = createToken(result.lastID, username);

    res.status(201).json({
      user: { id: result.lastID, username },
      token,
      message: 'Account created. Save your master PIN in a safe place!'
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// LOGIN
router.post('/login', async (req, res) => {
  try {
    const db = getDB();
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }

    // Find user
    const user = await db.get('SELECT * FROM users WHERE username = ?', [username]);
    if (!user) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }

    // Check password
    if (!comparePassword(password, user.password_hash)) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }

    const token = createToken(user.id, user.username);

    res.json({
      user: { id: user.id, username: user.username },
      token,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// RECOVER PASSWORD using Master PIN
router.post('/recover', async (req, res) => {
  try {
    const db = getDB();
    const { username, masterPin, newPassword } = req.body;

    if (!username || !masterPin || !newPassword) {
      return res.status(400).json({ error: 'Username, master PIN, and new password required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    // Find user
    const user = await db.get('SELECT * FROM users WHERE username = ?', [username]);
    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    // Verify Master PIN
    if (!comparePassword(masterPin, user.master_pin_hash)) {
      return res.status(401).json({ error: 'Invalid master PIN' });
    }

    // Update password
    const newPasswordHash = hashPassword(newPassword);
    await db.run('UPDATE users SET password_hash = ? WHERE id = ?', [newPasswordHash, user.id]);

    const token = createToken(user.id, user.username);

    res.json({
      user: { id: user.id, username },
      token,
      message: 'Password reset successfully',
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
