# Project Dashboard

A personal project tracking dashboard with offline-first sync, built for manual data entry and real-time updates.

## Features

- **Kanban Board**: Drag-free visual organization by status (Not Started / In Progress / Blocked / Done)
- **Health Indicators**: Automatic color coding (green/yellow/red) based on update recency
- **Offline-First**: Works without internet, syncs automatically when back online
- **Luxury Design**: Premium aesthetic with light/dark mode support
- **Roomy Cards**: Spacious, easy-to-read project cards
- **Quick Search**: Find projects by name or description
- **Rich Data Model**: Track accomplishments with dates, next actions, tags, links, notes, and more
- **Immediate Persistence**: Changes save instantly, no manual "Save" button

## Tech Stack

- **Frontend**: React 18 + TanStack Query (offline sync)
- **Backend**: Node.js + Express
- **Database**: SQLite (single-file, portable)
- **Hosting**: Railway (or local development)

## Setup & Installation

### Prerequisites

- Node.js 18+ installed
- npm or yarn

### 1. Install Dependencies

```bash
# Backend
cd backend
npm install

# Frontend
cd ../frontend
npm install
```

### 2. Start the Backend

```bash
cd backend
npm run dev
```

The server will run on `http://localhost:5000`.

### 3. Start the Frontend (in a new terminal)

```bash
cd frontend
npm run dev
```

The app will run on `http://localhost:5173` and open in your browser.

## Usage

### Creating Projects

1. Click **+ New Project** at the top
2. Enter the project name
3. The project is created with today's date and appears in the "Not Started" column

### Editing Projects

Click any project card to open the edit panel where you can:

- **Change Status**: Move between Not Started / In Progress / Blocked / Done
- **Add Accomplishments**: Log what you've done with dates (updates the health color)
- **Set Next Action**: Quick reminder of the next step
- **Add Tags**: Organize by categories
- **Add Links**: Store resources, documentation, etc.
- **Add Notes**: General notes about the project
- **Edit Description**: Longer context about the project

All changes save **immediately** — no "Save" button needed.

### Health Color Indicators

The color on the left edge of each card shows project health:

- 🟢 **Green**: Updated in the last 5 days (active)
- 🟡 **Yellow**: Stalled/Blocked status OR not updated in 6–9 days
- 🔴 **Red**: No work done OR not updated in 10+ days

### Filtering

Use the checkboxes below the header to show/hide columns by status.

### Searching

Use the search box at the top to find projects by name or description.

## Data Storage & Backup

### Where Is My Data?

All data is stored in a single SQLite file:

```
project-dashboard/backend/dashboard.db
```

This is a single portable file with everything.

### Backup Your Data

**Simple backup (copy the file):**
```bash
# On Windows (PowerShell)
Copy-Item "backend\dashboard.db" "backups\dashboard-$(Get-Date -Format 'yyyy-MM-dd-HHmm').db"

# On macOS/Linux
cp backend/dashboard.db backups/dashboard-$(date +%Y-%m-%d-%H%M).db
```

**Recommended**: Set up an automated backup (e.g., using a cron job or Windows Task Scheduler) to back up `dashboard.db` daily to cloud storage (Dropbox, Google Drive, etc.).

### Restore From Backup

Simply replace `backend/dashboard.db` with your backup file and restart the server.

## Customizing

### Change Colors

Edit the color variables in `frontend/src/index.css` in the `:root` section:

```css
:root {
  --color-not-started: #c9b7a8;    /* Gray-brown */
  --color-in-progress: #7ba4d6;    /* Blue */
  --color-blocked: #d4a574;        /* Amber */
  --color-done: #8db68c;           /* Green */

  --health-green: #5ba373;         /* Healthy */
  --health-yellow: #d4a25a;        /* Caution */
  --health-red: #a85a5a;           /* Needs attention */
}
```

### Change Light/Dark Mode

The app automatically follows your system setting. To force a specific mode, edit `frontend/src/index.css` and add:

```css
/* Force dark mode */
:root {
  color-scheme: dark;
  /* ... dark mode colors ... */
}
```

### Change Health Color Thresholds

Edit the `getHealthColor()` function in `frontend/src/components/ProjectCard.jsx`:

```javascript
function getHealthColor(project) {
  const daysSinceUpdate = /* ... calculate ... */;

  if (daysSinceUpdate <= 5) return 'green';      // ← Change 5
  if (daysSinceUpdate <= 9) return 'yellow';     // ← Change 9
  return 'red';
}
```

### Add a New Status Column

1. Edit `frontend/src/components/KanbanBoard.jsx` and update the `STATUSES` array:

```javascript
const STATUSES = [
  { key: 'not_started', label: 'Not Started' },
  { key: 'in_progress', label: 'In Progress' },
  { key: 'pending_review', label: 'Pending Review' },  // ← Add new
  { key: 'blocked', label: 'Blocked' },
  { key: 'done', label: 'Done' },
];
```

2. Update the status select in `frontend/src/components/EditPanel.jsx`:

```jsx
<select value={formData.status} onChange={...}>
  <option value="not_started">Not Started</option>
  <option value="in_progress">In Progress</option>
  <option value="pending_review">Pending Review</option>  {/* ← Add */}
  <option value="blocked">Blocked</option>
  <option value="done">Done</option>
</select>
```

3. Add a color for the new status in `frontend/src/index.css`:

```css
--color-pending-review: #b8a5c4;   /* Purple */
```

## Architecture Notes

### Future Product Features

This dashboard is architected to support adding a subscription product later without rewriting:

- **Database schema** includes `user_id` column on all tables (ready for multi-user)
- **API layer** is separate from frontend (easy to authenticate/authorize)
- Comments in `backend/db.js` and `backend/routes.js` mark where auth/billing/multi-tenancy would plug in

For now, it's single-user (you) with `user_id` hardcoded to 1. When adding auth later:
1. Replace `USER_ID = 1` with `USER_ID = req.user.id` (from auth middleware)
2. Add authentication middleware to verify tokens
3. All existing queries already filter by `user_id`, so data isolation is built-in

### Offline Sync Strategy

- **Service Worker** (`frontend/public/sw.js`) caches API responses and static assets
- **TanStack Query** retries failed requests and syncs in the background
- **localStorage** stores raw data for offline fallback
- When back online, queries automatically re-sync with the server

## Troubleshooting

### Backend won't start

- Ensure Node.js 18+ is installed: `node --version`
- Check that port 5000 is not in use: `netstat -ano | findstr :5000` (Windows)
- Delete any corrupted database: `rm backend/dashboard.db` and restart

### Frontend can't connect to backend

- Ensure backend is running on `http://localhost:5000`
- Check browser console for CORS errors
- Try `http://127.0.0.1:5000` instead of `localhost`

### Projects not appearing

- Open browser DevTools (F12) → Console → check for errors
- Check that API requests show success (Network tab)
- Ensure `backend/dashboard.db` exists and has data: `sqlite3 backend/dashboard.db "SELECT COUNT(*) FROM projects;"`

### Offline mode not working

- Check that service worker registered: DevTools → Application → Service Workers
- Browser must be served over HTTPS for production (localhost works without it)
- Data is cached in `localStorage` — check DevTools → Application → Local Storage

## Deployment to Railway

1. Create a Railway account at https://railway.app
2. Connect your GitHub repo (or upload this folder)
3. Set environment variable: `NODE_ENV=production`
4. Railway auto-detects Node.js and deploys
5. Update frontend `VITE_API_URL` to your Railway domain
6. Your dashboard is now live at a public URL

For details, see [Railway deployment docs](https://docs.railway.app).

## Future Ideas (You'll Discover After Using It)

- Bulk actions (mark multiple as done, assign multiple to a tag)
- Recurring projects (template-based)
- Timeline/Gantt view (by deadline instead of status)
- Syncing with external tools (if you want to later)
- Sharing with a team (multi-user, if the product grows)

Start with what you have. Build what you need.
