# Quick Start - Deploy to Hostinger in 5 Steps

## Step 1: Install Dependencies
```bash
cd "C:\Users\Kee\project dashboard"

cd backend && npm install && cd ..
cd frontend && npm install && cd ..
```

## Step 2: Create GitHub Account & Repository

1. Go to [github.com/new](https://github.com/new)
2. Create repository named `project-dashboard`
3. Copy your repository URL (looks like: `https://github.com/YOUR_USERNAME/project-dashboard.git`)

## Step 3: Push Code to GitHub

```bash
# Set your GitHub username and email
git config user.name "Your Name"
git config user.email "your-email@gmail.com"

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Project Dashboard for production"

# Add remote (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/project-dashboard.git

# Push to GitHub
git branch -M main
git push -u origin main
```

When prompted for password, use a GitHub Personal Access Token (create at https://github.com/settings/tokens)

## Step 4: Set Up Hostinger MySQL Database

1. Log in to Hostinger hPanel
2. Go to **Databases**
3. Create new MySQL database:
   - Name: `project_dashboard`
   - User: `project_dashboard_user`
   - Password: Generate strong password (copy it!)

## Step 5: Deploy on Hostinger

1. Go to your Hostinger Node.js website dashboard
2. Navigate to **Advanced → GIT**
3. Click **"Connect with GitHub"** and authorize
4. Select your `project-dashboard` repository
5. Select `main` branch
6. Set **Build Command:**
   ```
   npm run build --prefix frontend && npm install --prefix backend
   ```
7. Set **Start Command:**
   ```
   node backend/server.js
   ```
8. Add **Environment Variables:**
   ```
   NODE_ENV=production
   DB_TYPE=mysql
   DB_HOST=<hostinger-db-host>
   DB_USER=project_dashboard_user
   DB_PASSWORD=<your-database-password>
   DB_NAME=project_dashboard
   JWT_SECRET=<generate-random-string>
   CORS_ORIGIN=https://yourdomain.com
   ```

9. Click **Deploy**

## 🎉 Done!

Your app will be live at `https://yourdomain.com` in a few minutes!

### Make Future Updates:
```bash
git add .
git commit -m "Your changes"
git push origin main
```

Hostinger automatically redeploys!

## Detailed Guides Available:
- `DEPLOYMENT.md` - Full deployment guide
- `GITHUB_SETUP.md` - GitHub step-by-step
- `PRODUCTION_SETUP_SUMMARY.md` - Complete overview
