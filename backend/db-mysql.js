import mysql from 'mysql2/promise';

let connection = null;

export async function initDB() {
  if (connection) return connection;

  const config = {
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'project_dashboard',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
  };

  const pool = mysql.createPool(config);

  // Create database if it doesn't exist
  const poolConnection = await pool.getConnection();
  await poolConnection.query(
    `CREATE DATABASE IF NOT EXISTS ${process.env.DB_NAME || 'project_dashboard'}`
  );
  poolConnection.release();

  // Create tables
  const conn = await pool.getConnection();

  try {
    await conn.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        master_pin_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS projects (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        status VARCHAR(50) DEFAULT 'not_started',
        date_started VARCHAR(255) NOT NULL,
        next_action TEXT,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        KEY idx_user_id (user_id)
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS accomplishments (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        project_id INT NOT NULL,
        entry TEXT NOT NULL,
        date_logged VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,
        KEY idx_project_id (project_id)
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS project_tags (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        project_id INT NOT NULL,
        tag VARCHAR(255) NOT NULL,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,
        KEY idx_project_id (project_id)
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS project_links (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        project_id INT NOT NULL,
        title VARCHAR(255),
        url TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE,
        KEY idx_project_id (project_id)
      )
    `);

    console.log('MySQL database initialized successfully');
  } finally {
    conn.release();
  }

  connection = pool;
  return pool;
}

export function getDB() {
  if (!connection) throw new Error('Database not initialized');
  return connection;
}
