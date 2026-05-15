# Multi-User Setup Guide

Your dashboard now supports multiple users! Each person can have their own login and see only their own projects.

## What Changed

### Before (Single-User)
- One hardcoded user (USER_ID = 1)
- Anyone with the URL could see all projects

### Now (Multi-User)
- Each person has a username and password
- Each person logs in separately
- Each person sees only their own projects
- Data is completely isolated

---

## Quick Start: Demo Accounts

### Option A: Use Pre-Made Demo Accounts (Fastest)

1. **Seed the demo data:**
   ```powershell
   cd backend
   npm run seed-demo
   ```

2. **Demo accounts ready to use:**
   - User 1: `alice` / `password123`
   - User 2: `bob` / `password123`

Each demo user has sample projects to explore.

### Option B: Create Your Own Accounts

When you start the app:
1. You'll see a **Sign In** screen
2. Click **"Sign up"** to create a new account
3. Enter username and password (min 3 chars for username, 6 for password)
4. You're logged in — start creating projects

---

## How It Works

### Login Screen

When you first open http://localhost:5173:

- **Sign In**: Use existing username + password
- **Sign Up**: Create a new account
- Each user is completely separate

### Logout

Click **"Sign Out"** (top right) to:
- Log out the current user
- Return to the login screen
- Switch to another user

### Data Isolation

Each user sees only their own projects:
- Alice logs in → sees Alice's projects
- Bob logs in → sees Bob's projects
- Neither can see the other's data

---

## Behind the Scenes (Technical)

### What Was Added

**Backend:**
- `auth.js` — JWT token creation, password hashing
- `authRoutes.js` — `/api/auth/login` and `/api/auth/signup` endpoints
- Updated `routes.js` — All queries now filter by authenticated user ID
- Updated `db.js` — Added `users` table

**Frontend:**
- `AuthContext.jsx` — Manages login state, token storage
- `AuthPage.jsx` — Login/signup form
- `HowToUse.jsx` — Tutorial page (click the ? button)
- Updated `App.jsx` — Shows auth page if not logged in, shows dashboard if logged in

**Database:**
- New `users` table with username and password_hash
- All project tables now require `user_id` to match logged-in user
- Foreign key: projects → users (delete user → delete their projects)

### How Authentication Works

1. User signs up with username + password
2. Backend hashes password with SHA256 and stores in database
3. Backend creates a JWT token and sends to frontend
4. Frontend stores token in localStorage
5. On every API request, frontend sends token in Authorization header
6. Backend verifies token and extracts user ID
7. All queries filter by that user ID

**For local use:** Simple password hashing (SHA256) is fine. For production, upgrade to bcrypt.

---

## Managing Multiple Users (Different Computers)

### Scenario: You and Someone Else on Different Computers

1. **Your computer:**
   - Backend runs on `localhost:5000`
   - Frontend runs on `localhost:5173`
   - You log in locally

2. **Their computer:**
   - They set up their own backend + frontend (same code)
   - Backend runs on their `localhost:5000`
   - Frontend runs on their `localhost:5173`
   - They create an account and log in

Each person has their own database — **no data is shared**.

### Scenario: Sharing the Same Server

If you want to run one backend and have multiple people access it from different computers:

1. **Deploy to a server** (e.g., Railway — see README.md for instructions)
2. Each person visits your server URL (e.g., `https://my-dashboard.railway.app`)
3. They sign up / log in
4. They see only their projects

This is more advanced but doable. The architecture is ready for it.

---

## Demo User Projects

When you run `npm run seed-demo`, two demo users are created with sample projects:

### Alice's Projects
- **Learn React** (In Progress) — Has accomplishments logged, so it's green
- **Fitness Goal** (Not Started) — Waiting to be started

### Bob's Projects
- **Website Redesign** (Blocked) — Shows yellow (blocked = waiting)
- **Conference Talk** (In Progress) — Requires slides to be created

You can delete these demo projects or keep them as examples.

---

## Creating More Users

### Method 1: Sign Up in the App

1. Click "Sign up" on the login page
2. Create a username and password
3. Done!

### Method 2: SQL (Advanced)

If you want to create users directly in the database:

```powershell
# Open a PowerShell in your project
sqlite3 backend/dashboard.db

# Then in sqlite3:
INSERT INTO users (username, password_hash) VALUES ('dave', 'a87ff679a2f3e71d9181a67b7542122b6062a51a0d1d6f0d1c4c4c4c4c4c4c4');
```

(The hash above is SHA256 of "password123" — change it for a different password)

---

## Troubleshooting

### "Login Failed" Error

**Problem**: Username or password is wrong
**Solution**: Check spelling, or sign up for a new account

### "Unauthorized" on Dashboard

**Problem**: Token expired or invalid
**Solution**: Refresh the page or sign out and back in

### "Can't create account — username taken"

**Problem**: That username already exists
**Solution**: Choose a different username

### Demo users aren't showing up

**Problem**: Seed script wasn't run
**Solution**: Run `npm run seed-demo` in the backend folder

### Both users see the same projects

**Problem**: This shouldn't happen — database schema should prevent it
**Solution**: Check that you're signed in as different users. If the problem persists, delete `dashboard.db` and restart with fresh demo data.

---

## Upgrading Security (For Production)

If you eventually launch this as a product, upgrade:

### 1. Password Hashing
Replace SHA256 with bcrypt:
```javascript
// Install: npm install bcrypt
import bcrypt from 'bcrypt';
const passwordHash = await bcrypt.hash(password, 10);
const isValid = await bcrypt.compare(password, passwordHash);
```

### 2. JWT Secret
Replace the hardcoded secret in `auth.js`:
```javascript
const JWT_SECRET = process.env.JWT_SECRET; // Set in environment
```

### 3. HTTPS
Use HTTPS in production (Railway provides free SSL)

### 4. Email Verification
Add email verification on signup (see ARCHITECTURE_NOTES.md)

### 5. Rate Limiting
Prevent brute-force login attempts (use express-rate-limit)

---

## Next Steps

1. **Try it out**: Create a couple of accounts and explore
2. **Invite others**: They can run the same code on their computer, or you can deploy to a server
3. **Read the tutorial**: Click the ? button in the app for a detailed how-to

You now have a multi-user project dashboard! 🎉
