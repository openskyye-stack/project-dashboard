# GitHub Setup Guide - Project Dashboard

This guide walks you through setting up your Project Dashboard repository on GitHub and connecting it to Hostinger for automatic deployment.

## Prerequisites

- GitHub account (free or paid)
- Git installed on your computer
- Project Dashboard code ready for deployment

## Step 1: Create a GitHub Repository

### 1.1 Create New Repository on GitHub

1. Go to [github.com/new](https://github.com/new)
2. Fill in the repository details:
   - **Repository name**: `project-dashboard`
   - **Description**: `A multi-user project management dashboard with task tracking and authentication`
   - **Visibility**: Choose `Public` (recommended for easier Hostinger integration) or `Private`
   - **Initialize with**: Leave unchecked (we'll push existing code)
3. Click "Create repository"

### 1.2 Get Your Repository URL

After creating, you'll see your repository URL. It will look like:
```
https://github.com/YOUR_USERNAME/project-dashboard.git
```

Copy this URL - you'll need it in the next steps.

## Step 2: Set Up Git Locally

### 2.1 Configure Git (First Time Only)

If you haven't configured Git before:

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

### 2.2 Navigate to Project Directory

Open Command Prompt or PowerShell and navigate to your project:

```bash
cd "C:\Users\Kee\project dashboard"
```

## Step 3: Initialize Git Repository

### 3.1 Initialize Git

```bash
git init
```

This creates a `.git` folder in your project directory.

### 3.2 Add Remote Repository

Replace `YOUR_USERNAME` with your actual GitHub username:

```bash
git remote add origin https://github.com/YOUR_USERNAME/project-dashboard.git
```

### 3.3 Verify Remote Configuration

```bash
git remote -v
```

You should see:
```
origin  https://github.com/YOUR_USERNAME/project-dashboard.git (fetch)
origin  https://github.com/YOUR_USERNAME/project-dashboard.git (push)
```

## Step 4: Create Initial Commit

### 4.1 Install npm Dependencies (if not done)

```bash
cd backend
npm install

cd ../frontend
npm install

cd ..
```

### 4.2 Add All Files to Git

```bash
git add .
```

### 4.3 Create Initial Commit

```bash
git commit -m "Initial commit: Project Dashboard application setup for production deployment"
```

### 4.4 Rename Branch to main (if needed)

```bash
git branch -M main
```

## Step 5: Push to GitHub

### 5.1 Set Upstream and Push

```bash
git push -u origin main
```

On first push, you may be prompted to authenticate with GitHub. Choose one of these methods:

#### Option A: Personal Access Token (Recommended)
1. Go to [github.com/settings/tokens](https://github.com/settings/tokens)
2. Click "Generate new token" → "Generate new token (classic)"
3. Select scopes: `repo`, `admin:repo_hook`
4. Copy the token
5. When Git prompts for password, paste the token
6. Git will remember it for future pushes

#### Option B: SSH Key
If you have SSH configured, GitHub will use that automatically.

## Step 6: Verify on GitHub

1. Go to your repository: `https://github.com/YOUR_USERNAME/project-dashboard`
2. You should see all your files listed
3. Verify these important files are there:
   - `backend/server.js`
   - `backend/package.json`
   - `frontend/src/App.jsx`
   - `frontend/package.json`
   - `.gitignore`
   - `DEPLOYMENT.md`

## Step 7: Connect to Hostinger

Now that your code is on GitHub, connect it to Hostinger:

1. Log in to Hostinger
2. Go to your Node.js website dashboard
3. Navigate to: **Advanced → GIT**
4. Click "**Connect with GitHub**"
5. Authorize Hostinger to access your GitHub account
6. Select your `project-dashboard` repository
7. Select `main` branch
8. Configure deployment settings:

   **Build Command:**
   ```
   npm run build --prefix frontend && npm install --prefix backend
   ```

   **Start Command:**
   ```
   node backend/server.js
   ```

9. Set environment variables in Hostinger:
   ```
   NODE_ENV=production
   DB_TYPE=mysql
   DB_HOST=<your-hostinger-db-host>
   DB_USER=project_dashboard_user
   DB_PASSWORD=<your-secure-password>
   DB_NAME=project_dashboard
   JWT_SECRET=<random-secure-string>
   CORS_ORIGIN=https://yourdomain.com
   ```

10. Click Deploy

## Step 8: Make Future Updates

Once set up, deploying updates is easy:

```bash
# Make your changes locally
# Edit files as needed

# Stage changes
git add .

# Commit
git commit -m "Describe your changes here"

# Push to GitHub
git push origin main
```

Hostinger will automatically detect the push and redeploy your application!

## Common Git Commands

```bash
# Check status
git status

# View commit history
git log --oneline

# View changes before committing
git diff

# Undo uncommitted changes in a file
git checkout -- filename

# Undo last commit (keep changes)
git reset --soft HEAD~1

# View current remote
git remote -v
```

## Troubleshooting

### "fatal: not a git repository"
- Make sure you're in the correct directory
- Run `git init` again
- Check if `.git` folder exists

### "Authentication failed"
- Verify your GitHub username and personal access token
- Try: `git remote set-url origin https://YOUR_USERNAME@github.com/YOUR_USERNAME/project-dashboard.git`

### "Branch main set up to track origin/main"
- This is normal and means everything is working
- Push was successful

### Repository not showing on GitHub
- Make sure you pushed to `main` branch
- Check your GitHub account for the repository
- Verify you have internet connection

## Next Steps

1. Ensure MySQL database is created on Hostinger
2. Set all environment variables in Hostinger
3. Test the deployment from Hostinger dashboard
4. Create your admin account and test the application
5. Set up custom domain (if you have one)

## Security Notes

- **Never commit `.env` file** - it contains secrets
- **Never commit `node_modules`** - Hostinger will install them
- **Never commit `dashboard.db`** - SQLite file, not needed
- **Change `JWT_SECRET`** to a random string in production
- **Change `DB_PASSWORD`** to a strong password

Your `.gitignore` file already handles most of this, but be careful with sensitive files.

## Help Resources

- [GitHub Documentation](https://docs.github.com)
- [Git Tutorial](https://git-scm.com/docs)
- [Hostinger Knowledge Base](https://support.hostinger.com)
