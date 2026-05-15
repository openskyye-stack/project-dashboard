import { initDB, getDB } from './db.js';
import { hashPassword } from './auth.js';

async function seedDemo() {
  await initDB();
  const db = getDB();

  // Check if demo users already exist
  const alice = await db.get('SELECT id FROM users WHERE username = ?', ['alice']);
  if (alice) {
    console.log('Demo users already exist. Skipping seed.');
    return;
  }

  // Create demo users
  const alicePass = hashPassword('password123');
  const bobPass = hashPassword('password123');

  const alice_result = await db.run(
    'INSERT INTO users (username, password_hash) VALUES (?, ?)',
    ['alice', alicePass]
  );

  const bob_result = await db.run(
    'INSERT INTO users (username, password_hash) VALUES (?, ?)',
    ['bob', bobPass]
  );

  const aliceId = alice_result.lastID;
  const bobId = bob_result.lastID;

  // Create demo projects for Alice
  const p1 = await db.run(
    `INSERT INTO projects (user_id, name, description, status, date_started, next_action)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [aliceId, 'Learn React', 'Build a simple todo app', 'in_progress', '2026-05-10', 'Complete the hooks tutorial']
  );

  const p2 = await db.run(
    `INSERT INTO projects (user_id, name, description, status, date_started, next_action)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [aliceId, 'Fitness Goal', 'Run 3x per week', 'not_started', '2026-05-14', 'Sign up for gym']
  );

  // Add accomplishments for Alice's first project
  await db.run(
    `INSERT INTO accomplishments (user_id, project_id, entry, date_logged)
     VALUES (?, ?, ?, ?)`,
    [aliceId, p1.lastID, 'Learned useState and useEffect', '2026-05-13']
  );

  await db.run(
    `INSERT INTO accomplishments (user_id, project_id, entry, date_logged)
     VALUES (?, ?, ?, ?)`,
    [aliceId, p1.lastID, 'Built a simple counter component', '2026-05-14']
  );

  // Add tags for Alice's projects
  await db.run(
    'INSERT INTO project_tags (user_id, project_id, tag) VALUES (?, ?, ?)',
    [aliceId, p1.lastID, 'learning']
  );

  await db.run(
    'INSERT INTO project_tags (user_id, project_id, tag) VALUES (?, ?, ?)',
    [aliceId, p2.lastID, 'personal']
  );

  // Create demo projects for Bob
  const p3 = await db.run(
    `INSERT INTO projects (user_id, name, description, status, date_started, next_action)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [bobId, 'Website Redesign', 'Update company homepage', 'blocked', '2026-05-08', 'Waiting for client feedback']
  );

  const p4 = await db.run(
    `INSERT INTO projects (user_id, name, description, status, date_started, next_action)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [bobId, 'Conference Talk', 'Prepare presentation on AI', 'in_progress', '2026-05-11', 'Create slides']
  );

  await db.run(
    `INSERT INTO accomplishments (user_id, project_id, entry, date_logged)
     VALUES (?, ?, ?, ?)`,
    [bobId, p4.lastID, 'Outlined main points and structure', '2026-05-12']
  );

  await db.run(
    'INSERT INTO project_tags (user_id, project_id, tag) VALUES (?, ?, ?)',
    [bobId, p3.lastID, 'work']
  );

  await db.run(
    'INSERT INTO project_tags (user_id, project_id, tag) VALUES (?, ?, ?)',
    [bobId, p4.lastID, 'speaking']
  );

  console.log('✅ Demo users created:');
  console.log('  User 1: alice / password123');
  console.log('  User 2: bob / password123');
  console.log('Each user has sample projects to explore.');
}

seedDemo().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
