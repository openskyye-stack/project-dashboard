import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { authMiddleware } from './auth.js';
import authRoutes from './authRoutes.js';
import adminRoutes from './adminRoutes.js';
import routes from './routes.js';

const dbModule = await (process.env.NODE_ENV === 'production'
  ? import('./db-mysql.js')
  : import('./db.js'));
const { initDB } = dbModule;

const app = express();
const PORT = process.env.PORT || 5000;
const HOST = process.env.HOST || 'localhost';

app.use(cors({
  origin: process.env.CORS_ORIGIN || '*'
}));
app.use(express.json());

// Public auth routes (no token required)
app.use('/api/auth', authRoutes);

// Admin routes (no token required for local use)
app.use('/api/admin', adminRoutes);

// Protected routes (require token)
app.use('/api', authMiddleware, routes);

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

async function start() {
  try {
    await initDB();
    const env = process.env.NODE_ENV || 'development';
    const dbType = process.env.DB_TYPE || 'sqlite';
    console.log(`Starting server in ${env} mode with ${dbType} database`);

    app.listen(PORT, HOST, () => {
      console.log(`Server running on http://${HOST}:${PORT}`);
    });
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

start().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
