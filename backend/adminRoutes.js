import express from 'express';
import { getDB } from './db.js';
import { hashPassword } from './auth.js';

const router = express.Router();

// List all users - for admin panel
// NOTE: No auth required since this is a local app. For production, add auth!
router.get('/users', async (req, res) => {
  try {
    const db = getDB();
    const users = await db.all('SELECT id, username, created_at FROM users ORDER BY created_at DESC');
    res.json(users);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Reset user password by admin - generates temporary password
// NOTE: No auth required for local use. In production, add admin authentication!
router.post('/reset-password/:userId', async (req, res) => {
  try {
    const db = getDB();
    const { userId } = req.params;
    const { newPassword } = req.body;

    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    // Verify user exists
    const user = await db.get('SELECT id, username FROM users WHERE id = ?', [userId]);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Update password
    const newPasswordHash = hashPassword(newPassword);
    await db.run(
      'UPDATE users SET password_hash = ? WHERE id = ?',
      [newPasswordHash, userId]
    );

    res.json({
      message: `Password reset for user ${user.username}`,
      user: { id: user.id, username: user.username },
      note: 'Share the new password with the user securely'
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get user details (for admin debugging)
router.get('/user/:userId', async (req, res) => {
  try {
    const db = getDB();
    const { userId } = req.params;

    const user = await db.get(
      'SELECT id, username, created_at FROM users WHERE id = ?',
      [userId]
    );

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(user);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
