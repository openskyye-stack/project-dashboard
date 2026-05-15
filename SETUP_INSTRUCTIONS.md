# Complete Setup Instructions

Your project dashboard is ready to run. Follow these steps to get it working.

## Step 1: Install Node.js

Download from https://nodejs.org (choose the LTS version).

After installation, verify it worked:
- Open PowerShell or Command Prompt
- Type: `node --version` and `npm --version`
- You should see version numbers (e.g., `v18.17.0`)

## Step 2: Install Dependencies

Open PowerShell in the `project dashboard` folder and run:

```powershell
# Install backend dependencies
cd backend
npm install

# Install frontend dependencies
cd ../frontend
npm install
```

This will take 2–3 minutes. You'll see a lot of output but no errors.

## Step 3: Start the Backend

**Keep this terminal open the entire time you're using the app.**

```powershell
cd backend
npm run dev
```

You should see:
```
Server running on http://localhost:5000
```

## Step 4: Start the Frontend (Open a New PowerShell Window)

**Do not close the backend terminal.**

```powershell
cd frontend
npm run dev
```

You should see something like:
```
  ➜  Local:   http://localhost:5173/
```

## Step 5: Open in Browser

Click the link in the terminal, or open http://localhost:5173 in your browser.

Your dashboard should appear with an empty Kanban board. **Create your first project!**

---

## Daily Usage

Every time you want to use the dashboard:

1. **Open Terminal 1** → `cd backend && npm run dev`
2. **Open Terminal 2** → `cd frontend && npm run dev`
3. **Open browser** → http://localhost:5173

When you're done, press **Ctrl+C** in both terminals to stop.

---

## If Something Goes Wrong

### "npm: command not found"
- Node.js didn't install correctly
- Restart your computer after installing Node.js
- Or reinstall Node.js from https://nodejs.org

### "Port 5000 already in use"
- Another app is using port 5000
- Either: close that app, or change the port in `backend/server.js` (line 5: change `5000` to another number like `5001`)

### "Cannot find module..."
- Run `npm install` again in that folder (backend or frontend)
- Or delete the `node_modules` folder and run `npm install` fresh

### "Blank page / nothing loads"
- Make sure backend is running (you should see "Server running..." message)
- Check that frontend is running on http://localhost:5173
- Refresh the page (Ctrl+R or Cmd+R)
- Open browser console (F12) and look for red errors

---

## Backing Up Your Data

Your projects are stored in one file:

```
project-dashboard/backend/dashboard.db
```

**To backup:**
1. Navigate to `project-dashboard/backend/`
2. Find `dashboard.db`
3. Copy it to a safe location (Dropbox, Google Drive, USB drive, etc.)
4. Name it with a date: `dashboard-2026-05-14.db`

**To restore from backup:**
1. Stop both terminals (Ctrl+C)
2. Replace `backend/dashboard.db` with your backup file
3. Start the app again

---

## Next Steps

Once it's running:

1. Read **QUICK_START.md** for daily usage tips
2. Read **README.md** for feature details and customization
3. Start creating projects and tracking your work!

---

## Keeping It Running (Optional: Run on Startup)

If you want the dashboard to launch automatically when you restart your computer:

**Windows Batch File Approach:**

1. Create a new file: `start-dashboard.bat` in the `project dashboard` folder
2. Paste this:

```batch
@echo off
start cmd /k "cd backend && npm run dev"
timeout /t 2
start cmd /k "cd frontend && npm run dev"
echo Both servers started. Open http://localhost:5173 in your browser.
pause
```

3. Double-click `start-dashboard.bat` to start everything at once

---

## Troubleshooting with More Detail

**Check what's running:**

In PowerShell:
```powershell
# See if port 5000 is in use
netstat -ano | findstr :5000

# See if port 5173 is in use
netstat -ano | findstr :5173
```

**Kill a process manually:**
```powershell
# Kill whatever is using port 5000 (replace PID with the number from netstat)
taskkill /PID <PID> /F

# Example:
taskkill /PID 12345 /F
```

**Check the database:**
```powershell
# Make sure the database file exists
Test-Path "backend/dashboard.db"

# If you want to inspect it, install SQLite tools (optional)
# Then: sqlite3 backend/dashboard.db
```

---

## Questions?

Refer to:
- **QUICK_START.md** — Daily usage and tips
- **README.md** — Features, customization, troubleshooting
- **ARCHITECTURE_NOTES.md** — How to add features later

You're all set! 🚀
