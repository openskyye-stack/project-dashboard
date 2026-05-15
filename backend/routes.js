import express from 'express';
import { getDB } from './db.js';

const router = express.Router();

// NOTE: All routes are protected by authMiddleware.
// req.user.userId is populated from the JWT token.

// GET all projects with related data
router.get('/projects', async (req, res) => {
  try {
    const db = getDB();
    const projects = await db.all(
      'SELECT * FROM projects WHERE user_id = ? ORDER BY updated_at DESC',
      [req.user.userId]
    );

    for (let project of projects) {
      project.accomplishments = await db.all(
        'SELECT * FROM accomplishments WHERE project_id = ? ORDER BY date_logged DESC',
        [project.id]
      );
      project.tags = (await db.all(
        'SELECT tag FROM project_tags WHERE project_id = ?',
        [project.id]
      )).map(t => t.tag);
      project.links = await db.all(
        'SELECT id, title, url FROM project_links WHERE project_id = ?',
        [project.id]
      );
    }

    res.json(projects);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET single project
router.get('/projects/:id', async (req, res) => {
  try {
    const db = getDB();
    const project = await db.get(
      'SELECT * FROM projects WHERE id = ? AND user_id = ?',
      [req.params.id, req.user.userId]
    );
    if (!project) return res.status(404).json({ error: 'Not found' });

    project.accomplishments = await db.all(
      'SELECT * FROM accomplishments WHERE project_id = ? ORDER BY date_logged DESC',
      [project.id]
    );
    project.tags = (await db.all(
      'SELECT tag FROM project_tags WHERE project_id = ?',
      [project.id]
    )).map(t => t.tag);
    project.links = await db.all(
      'SELECT id, title, url FROM project_links WHERE project_id = ?',
      [project.id]
    );

    res.json(project);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// CREATE project
router.post('/projects', async (req, res) => {
  try {
    const db = getDB();
    const { name, description, status, date_started, next_action, notes } = req.body;

    if (!name || !date_started) {
      return res.status(400).json({ error: 'name and date_started required' });
    }

    const result = await db.run(
      `INSERT INTO projects (user_id, name, description, status, date_started, next_action, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [req.user.userId, name, description || null, status || 'not_started', date_started, next_action || null, notes || null]
    );

    const project = await db.get('SELECT * FROM projects WHERE id = ?', [result.lastID]);
    project.accomplishments = [];
    project.tags = [];
    project.links = [];

    res.status(201).json(project);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// UPDATE project
router.put('/projects/:id', async (req, res) => {
  try {
    const db = getDB();
    const { name, description, status, next_action, notes } = req.body;

    await db.run(
      `UPDATE projects SET name = ?, description = ?, status = ?, next_action = ?, notes = ?, updated_at = CURRENT_TIMESTAMP
       WHERE id = ? AND user_id = ?`,
      [name, description, status, next_action, notes, req.params.id, req.user.userId]
    );

    const project = await db.get('SELECT * FROM projects WHERE id = ?', [req.params.id]);
    if (!project) return res.status(404).json({ error: 'Not found' });

    project.accomplishments = await db.all(
      'SELECT * FROM accomplishments WHERE project_id = ? ORDER BY date_logged DESC',
      [project.id]
    );
    project.tags = (await db.all(
      'SELECT tag FROM project_tags WHERE project_id = ?',
      [project.id]
    )).map(t => t.tag);
    project.links = await db.all(
      'SELECT id, title, url FROM project_links WHERE project_id = ?',
      [project.id]
    );

    res.json(project);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE project
router.delete('/projects/:id', async (req, res) => {
  try {
    const db = getDB();
    await db.run('DELETE FROM projects WHERE id = ? AND user_id = ?', [req.params.id, req.user.userId]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ADD accomplishment
router.post('/projects/:id/accomplishments', async (req, res) => {
  try {
    const db = getDB();
    const { entry, date_logged } = req.body;

    if (!entry || !date_logged) {
      return res.status(400).json({ error: 'entry and date_logged required' });
    }

    const result = await db.run(
      `INSERT INTO accomplishments (user_id, project_id, entry, date_logged)
       VALUES (?, ?, ?, ?)`,
      [req.user.userId, req.params.id, entry, date_logged]
    );

    // Update project updated_at
    await db.run('UPDATE projects SET updated_at = CURRENT_TIMESTAMP WHERE id = ?', [req.params.id]);

    const accomplishment = await db.get(
      'SELECT * FROM accomplishments WHERE id = ?',
      [result.lastID]
    );

    res.status(201).json(accomplishment);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE accomplishment
router.delete('/accomplishments/:id', async (req, res) => {
  try {
    const db = getDB();
    const acc = await db.get('SELECT project_id FROM accomplishments WHERE id = ?', [req.params.id]);
    if (!acc) return res.status(404).json({ error: 'Not found' });

    await db.run('DELETE FROM accomplishments WHERE id = ?', [req.params.id]);
    await db.run('UPDATE projects SET updated_at = CURRENT_TIMESTAMP WHERE id = ?', [acc.project_id]);

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// UPDATE tags
router.put('/projects/:id/tags', async (req, res) => {
  try {
    const db = getDB();
    const { tags } = req.body;

    await db.run('DELETE FROM project_tags WHERE project_id = ?', [req.params.id]);

    for (let tag of tags || []) {
      await db.run(
        'INSERT INTO project_tags (user_id, project_id, tag) VALUES (?, ?, ?)',
        [req.user.userId, req.params.id, tag]
      );
    }

    await db.run('UPDATE projects SET updated_at = CURRENT_TIMESTAMP WHERE id = ?', [req.params.id]);

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// UPDATE links
router.put('/projects/:id/links', async (req, res) => {
  try {
    const db = getDB();
    const { links } = req.body;

    await db.run('DELETE FROM project_links WHERE project_id = ?', [req.params.id]);

    for (let link of links || []) {
      await db.run(
        'INSERT INTO project_links (user_id, project_id, title, url) VALUES (?, ?, ?, ?)',
        [req.user.userId, req.params.id, link.title || null, link.url]
      );
    }

    await db.run('UPDATE projects SET updated_at = CURRENT_TIMESTAMP WHERE id = ?', [req.params.id]);

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
