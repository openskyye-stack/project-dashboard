# Architecture Notes: Future Product Expansion

This document marks the extension points for adding subscription product features (multi-user, auth, billing) without major refactoring.

## Current State

- **Single user**: `USER_ID = 1` (hardcoded in backend routes)
- **No authentication**: Anyone with API access can modify projects
- **No billing**: No subscription logic
- **No multi-tenancy**: Database schema supports it, but not enforced

## Extension Points

### 1. Authentication (User Login)

**Location**: `backend/routes.js`, line 1

Current:
```javascript
const USER_ID = 1; // Single user
```

To add auth later:
```javascript
const USER_ID = req.user.id; // From JWT token or session
```

**Frontend changes needed**:
- Add login/signup forms
- Store JWT token in localStorage
- Send token in API request headers

**Middleware to add**:
```javascript
// backend/middleware/auth.js
function verifyToken(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  // Verify JWT and set req.user
  next();
}

// Use in routes:
router.get('/projects', verifyToken, (req, res) => { ... });
```

### 2. Multi-Tenancy (Multiple Users)

**Database schema is ready**: All tables have `user_id` column.

**Queries already filter by user**:
```javascript
// Example in routes.js
await db.all('SELECT * FROM projects WHERE user_id = ?', [USER_ID]);
```

**What's needed**:
- Ensure `USER_ID` comes from authenticated request (see Auth section above)
- Add database constraint (if needed): `UNIQUE(user_id, project_name)` to prevent duplicates within a user
- Frontend doesn't need changes (already sends requests to `/api/projects`, which is per-user)

### 3. Billing & Subscriptions

**Location**: `backend/routes.js`, add new routes

Example structure:
```javascript
// backend/routes/billing.js
router.post('/billing/checkout', async (req, res) => {
  // Create Stripe checkout session
  // Store subscription data
});

router.get('/billing/subscription', verifyToken, async (req, res) => {
  // Check if user has active subscription
});
```

**Database changes**:
```sql
-- Add to db.js in initDB()
CREATE TABLE IF NOT EXISTS subscriptions (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL UNIQUE,
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  status TEXT, -- active, canceled, past_due
  current_period_end TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Feature limits per tier (optional)
CREATE TABLE IF NOT EXISTS feature_limits (
  user_id INTEGER PRIMARY KEY,
  max_projects INTEGER DEFAULT 20,
  max_team_members INTEGER DEFAULT 1,
  custom_fields BOOLEAN DEFAULT FALSE,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

**Enforcement**:
```javascript
// Check subscription before allowing API access
function requireActiveSubscription(req, res, next) {
  const subscription = await db.get(
    'SELECT status FROM subscriptions WHERE user_id = ? AND status = "active"',
    [req.user.id]
  );
  if (!subscription) return res.status(403).json({ error: 'Subscription required' });
  next();
}
```

### 4. User Management

**Location**: `backend/routes/users.js` (new file)

```javascript
router.post('/users/signup', async (req, res) => {
  const { email, password } = req.body;
  // Hash password, create user, send verification email
});

router.post('/users/login', async (req, res) => {
  // Verify email/password, issue JWT token
});

router.post('/users/logout', verifyToken, async (req, res) => {
  // Invalidate token
});
```

**Database changes**:
```sql
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  verified BOOLEAN DEFAULT FALSE
);
```

### 5. Data Isolation

**Currently**: `USER_ID = 1` means all data is visible to "user 1" only.

**When multi-user launches**:
- Each API query filters by authenticated `user_id`
- Database constraints ensure users can't access each other's data
- No UI changes needed — frontend queries `/api/projects` and gets filtered results

**Edge case to handle**:
- When deleting a user, cascade-delete all their projects (already set up with `ON DELETE CASCADE`)

## Implementation Checklist

When ready to launch the product:

- [ ] Add `users` table to database schema
- [ ] Add `subscriptions` table for billing
- [ ] Create auth middleware (`backend/middleware/auth.js`)
- [ ] Create user routes (`backend/routes/users.js`)
- [ ] Create billing routes (`backend/routes/billing.js`)
- [ ] Replace `USER_ID = 1` with `USER_ID = req.user.id` in all routes
- [ ] Add login/signup forms to frontend
- [ ] Add token handling (localStorage, request headers)
- [ ] Integrate Stripe or other payment processor
- [ ] Add email verification (nodemailer or SendGrid)
- [ ] Write tests for multi-user data isolation
- [ ] Deploy to Railway with proper environment variables

## Testing Multi-User Before Launch

Before going live with billing:

```javascript
// Create two test users and verify isolation
const user1Projects = await db.all(
  'SELECT * FROM projects WHERE user_id = ?',
  [1]
);
const user2Projects = await db.all(
  'SELECT * FROM projects WHERE user_id = ?',
  [2]
);
// Ensure user1Projects !== user2Projects
assert(user1Projects.length > 0 && user2Projects.length > 0);
assert(user1Projects[0].user_id !== user2Projects[0].user_id);
```

## Cost Estimates (Rough)

- **Stripe**: No setup fee, 2.9% + $0.30 per transaction
- **Email**: SendGrid ($20–$150/month) or AWS SES ($0.10 per 1000 emails)
- **Database**: SQLite is free; upgrade to PostgreSQL on Railway (~$15/month) if needed
- **Hosting**: Railway ($5–50/month depending on usage)

## Performance Considerations

When scaling to many users:

1. **Index by user_id**: Already done in `db.js` (see `CREATE INDEX idx_projects_user_id`)
2. **Pagination**: Add `LIMIT` and `OFFSET` to project queries if users have 1000+ projects
3. **Caching**: Consider Redis for session storage / subscription status
4. **Database**: SQLite is single-file but may need migration to PostgreSQL for concurrent writes

## Security Checklist

- [ ] Use HTTPS only (Railway provides free SSL)
- [ ] Hash passwords with bcrypt (never store plaintext)
- [ ] Use secure JWT signing key (not hardcoded)
- [ ] Validate all user inputs server-side
- [ ] Rate-limit login attempts (prevent brute force)
- [ ] Implement CORS properly
- [ ] Sanitize database queries (use parameterized queries — already done)
- [ ] Log auth failures and suspicious activity
- [ ] Encrypt sensitive data in transit (HTTPS) and at rest (if needed)

---

**Current Status**: Personal single-user dashboard. Zero product code. Full foundation ready for product launch when needed.
