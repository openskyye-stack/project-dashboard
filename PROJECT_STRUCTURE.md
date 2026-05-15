# Project Structure

## Directory Layout

```
project-dashboard/
├── backend/                      # Node.js + Express server
│   ├── package.json             # Backend dependencies
│   ├── server.js                # Main server (port 5000)
│   ├── db.js                    # SQLite database setup & schema
│   ├── routes.js                # REST API endpoints
│   ├── .env.example             # Environment template (for future)
│   └── dashboard.db             # Your data (created on first run)
│
├── frontend/                     # React app
│   ├── package.json             # Frontend dependencies
│   ├── vite.config.js          # Build tool config
│   ├── index.html              # HTML entry point
│   ├── public/
│   │   └── sw.js               # Service Worker (offline support)
│   └── src/
│       ├── main.jsx            # App initialization
│       ├── App.jsx             # Main component & layout
│       ├── App.css             # App styles
│       ├── index.css           # Global styles (colors, themes)
│       ├── queryClient.js      # Offline sync config
│       └── components/
│           ├── KanbanBoard.jsx       # Kanban board layout
│           ├── KanbanBoard.css       # Kanban styles
│           ├── ProjectCard.jsx       # Project card with health color
│           ├── ProjectCard.css       # Card styles
│           ├── EditPanel.jsx         # Edit form & details
│           └── EditPanel.css         # Panel styles
│
├── README.md                   # Full documentation
├── QUICK_START.md             # Daily usage guide
├── SETUP_INSTRUCTIONS.md      # Installation steps
├── ARCHITECTURE_NOTES.md      # Future product expansion
├── PROJECT_STRUCTURE.md       # This file
└── .gitignore                 # Git ignore rules
```

## What Each File Does

### Backend (`backend/`)

**server.js**
- Starts the Express server on port 5000
- Sets up CORS and JSON parsing
- Initializes the database

**db.js**
- Creates/opens the SQLite database
- Defines the schema (4 tables: projects, accomplishments, tags, links)
- Includes comments for future multi-user support

**routes.js**
- REST API endpoints: GET, POST, PUT, DELETE
- `/api/projects` — manage projects
- `/api/projects/:id/accomplishments` — track progress
- `/api/projects/:id/tags` — manage tags
- `/api/projects/:id/links` — store resources
- All queries filter by `user_id` (ready for multi-user)

**package.json**
- Dependencies: express, cors, sqlite3, sqlite
- Scripts: `npm run dev` (nodemon watch), `npm start` (production)

### Frontend (`frontend/`)

**index.html**
- Single HTML file that loads React

**main.jsx**
- Initializes React and mounts the app
- Sets up TanStack Query for API/offline sync

**App.jsx**
- Main app component
- Handles filtering, search, project creation
- Manages the Kanban board state

**queryClient.js**
- Configures offline-first caching
- Stores API responses in localStorage
- Registers the service worker for offline mode

**components/KanbanBoard.jsx**
- Renders 4 columns (Not Started, In Progress, Blocked, Done)
- Maps projects to columns
- Handles card click to open edit panel

**components/ProjectCard.jsx**
- Individual project card
- Shows title, description, next action, tags, update status
- Health color logic (green/yellow/red based on days since update)

**components/EditPanel.jsx**
- Slide-out panel for editing projects
- Forms for all project fields
- Add/remove accomplishments, tags, links
- Save/delete project buttons

**public/sw.js**
- Service Worker for offline support
- Caches API responses and static assets
- Network-first for API calls, cache-first for assets
- Syncs when back online

**package.json**
- Dependencies: react, react-dom, @tanstack/react-query
- Dev dependencies: vite, @vitejs/plugin-react
- Scripts: `npm run dev` (dev server), `npm run build` (production build)

**vite.config.js**
- Configures Vite build tool
- Proxies API calls to localhost:5000
- Defines environment variables

### Styles

**index.css** (Global)
- CSS variables for colors, spacing, shadows
- Light/dark mode support (auto-follows system)
- Status colors (not-started, in-progress, blocked, done)
- Health indicator colors (green, yellow, red)
- Base styles for buttons, inputs, scrollbars

**App.css** (Layout)
- Header with search and filters
- Main Kanban board container
- Responsive grid layout

**KanbanBoard.css**
- 4-column grid
- Column styling with status-based header colors
- Card container within each column

**ProjectCard.css**
- Card appearance and hover effects
- Health indicator bar (left edge)
- Title, description, next action styling
- Tags and metadata layout

**EditPanel.css**
- Slide-in panel animation
- Form groups and inputs
- Tag chips, link items, accomplishment list
- Close, save, delete buttons

### Documentation

**README.md**
- Complete feature list
- Setup instructions (already covered in SETUP_INSTRUCTIONS.md but more detailed)
- Usage guide
- Data storage & backup
- Customization options
- Troubleshooting
- Deployment to Railway

**QUICK_START.md**
- First-time setup summary
- Everyday usage tips
- Search & filter guide
- Health color explanation
- Backup procedures
- Copy-paste customizations
- Keyboard shortcuts and best practices

**SETUP_INSTRUCTIONS.md**
- Step-by-step installation (this is your main starting point)
- Running the app daily
- Daily usage quick ref
- Backup instructions
- Troubleshooting

**ARCHITECTURE_NOTES.md**
- Extension points for future product features
- How to add authentication (multi-user)
- How to add billing (subscriptions)
- How to add user management
- Database schema for future tables
- Security checklist

**PROJECT_STRUCTURE.md**
- This file

**.gitignore**
- Ignores node_modules, dist, .env, database.db, etc.
- Standard Node.js gitignore

---

## Data Flow

### Creating a Project

1. User clicks "+ New Project"
2. Browser → POST /api/projects → Backend
3. Backend → Inserts into SQLite projects table
4. Backend → Returns new project with ID
5. Frontend → Updates local cache, re-renders Kanban board
6. User sees project in "Not Started" column

### Editing a Project (e.g., adding an accomplishment)

1. User clicks project card
2. EditPanel opens with current project data
3. User adds accomplishment entry + date
4. Browser → POST /api/projects/:id/accomplishments → Backend
5. Backend → Inserts into accomplishments table
6. Backend → Updates projects.updated_at to now
7. Frontend → Refetches projects list
8. Health color recalculates (days since latest accomplishment)
9. Card color updates from yellow → green (if recently updated)

### Offline Mode

1. User loses internet connection
2. Mutation fails, but TanStack Query retries with backoff
3. Data is still stored in localStorage
4. Service Worker serves cached API responses
5. User can still edit (optimistic updates)
6. When back online, failed mutations sync automatically
7. Server applies updates to database

---

## API Endpoints

All endpoints are at `http://localhost:5000/api/`

### Projects

- `GET /projects` — List all projects
- `GET /projects/:id` — Get single project with all related data
- `POST /projects` — Create project (requires: name, date_started)
- `PUT /projects/:id` — Update project (name, description, status, next_action, notes)
- `DELETE /projects/:id` — Delete project

### Accomplishments

- `POST /projects/:id/accomplishments` — Add accomplishment (requires: entry, date_logged)
- `DELETE /accomplishments/:id` — Delete accomplishment

### Tags

- `PUT /projects/:id/tags` — Update tags (body: { tags: ["tag1", "tag2"] })

### Links

- `PUT /projects/:id/links` — Update links (body: { links: [{ title, url }, ...] })

### Health Check

- `GET /health` — Returns `{"status":"ok"}` if server is running

---

## Database Schema

### projects

```sql
CREATE TABLE projects (
  id INTEGER PRIMARY KEY,
  user_id INTEGER DEFAULT 1,        -- Future: multi-user
  name TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'not_started', -- not_started, in_progress, blocked, done
  date_started TEXT NOT NULL,
  next_action TEXT,
  notes TEXT,
  created_at TEXT,
  updated_at TEXT                   -- Updated when any field or accomplishment changes
);
```

### accomplishments

```sql
CREATE TABLE accomplishments (
  id INTEGER PRIMARY KEY,
  user_id INTEGER DEFAULT 1,        -- Future: multi-user
  project_id INTEGER NOT NULL,      -- Foreign key to projects
  entry TEXT NOT NULL,              -- What was done
  date_logged TEXT NOT NULL,        -- When it was done (YYYY-MM-DD)
  created_at TEXT
);
```

### project_tags

```sql
CREATE TABLE project_tags (
  id INTEGER PRIMARY KEY,
  user_id INTEGER DEFAULT 1,        -- Future: multi-user
  project_id INTEGER NOT NULL,
  tag TEXT NOT NULL
);
```

### project_links

```sql
CREATE TABLE project_links (
  id INTEGER PRIMARY KEY,
  user_id INTEGER DEFAULT 1,        -- Future: multi-user
  project_id INTEGER NOT NULL,
  title TEXT,                       -- Optional display name
  url TEXT NOT NULL,                -- The actual link
  created_at TEXT
);
```

All tables have indexes on `project_id` and `user_id` for fast queries.

---

## Key Design Decisions

1. **Single-file database (SQLite)**: Easy to backup, no external dependencies
2. **Offline-first**: Service Worker + localStorage + TanStack Query caching
3. **Immediate persistence**: No "Save" button — changes sync to server instantly (even offline)
4. **User ID column in all tables**: Zero product code yet, but architecture ready for multi-user
5. **Luxury aesthetic**: Generous spacing, premium colors, light/dark mode auto-detect
6. **Health colors automatic**: Based on accomplishment dates, no manual "progress" slider
7. **Roomy cards**: Prefer readability over fitting more projects on screen
8. **Clean API layer**: Frontend never touches the database directly

---

## What's NOT Included (Yet)

- Authentication / Login
- Multi-user support
- Billing / Subscriptions
- Database backups (you handle manually, see README)
- Email notifications
- Sharing with others
- Mobile app (web app is responsive, but not optimized for phone)
- Drag-and-drop (cards are click-to-move-status)
- Recurring projects
- Gantt chart / timeline view
- Bulk actions
- Project templates
- Search filters (only basic text search)

These are all easy to add later. See ARCHITECTURE_NOTES.md for guidance.

---

## Files You'll Modify Most Often

1. **frontend/src/index.css** — Change colors or spacing
2. **frontend/src/components/*.jsx** — Tweak layouts or add features
3. **backend/routes.js** — Add new API endpoints
4. **README.md** / **QUICK_START.md** — Update docs as you discover needs

## Files You Probably Won't Touch

- Vite config (unless upgrading Vite)
- Service Worker (unless offline strategy changes)
- Database schema (unless adding new data types)
- Package.json (unless adding dependencies)

---

## Summary

- **Backend**: Node.js Express server, SQLite database, clean API layer
- **Frontend**: React + Vite, offline sync with TanStack Query, luxury CSS
- **Data**: Single database.db file, easy to backup
- **Ready for**: Adding auth, multi-user, billing without refactoring

You're set to start tracking projects! 🚀
