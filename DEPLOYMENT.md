# Project Dashboard - Deployment Guide

## Production Setup on Hostinger

This guide covers deploying the Project Dashboard to Hostinger's Node.js hosting.

### Prerequisites

- Hostinger Node.js hosting account
- GitHub account with Git repository
- MySQL database (available through Hostinger)

### Step 1: Prepare the Code for Production

#### 1.1 Install Dependencies
```bash
cd backend
npm install
cd ../frontend
npm install
```

#### 1.2 Build Frontend
```bash
cd frontend
npm run build
```

The built files will be in `frontend/dist/`.

### Step 2: Set Up GitHub Repository

#### 2.1 Initialize Git (if not already done)
```bash
git init
git add .
git commit -m "Initial commit: Project Dashboard application"
```

#### 2.2 Push to GitHub
```bash
git remote add origin https://github.com/YOUR_USERNAME/project-dashboard.git
git branch -M main
git push -u origin main
```

### Step 3: Configure Hostinger MySQL Database

1. Log in to Hostinger hPanel
2. Go to Databases section
3. Create a new MySQL database with:
   - Database name: `project_dashboard`
   - User: `project_dashboard_user`
   - Password: (use a strong, unique password)
   - Host: `localhost` (or provided by Hostinger)

Note down the connection details.

### Step 4: Connect GitHub to Hostinger

1. Go to your Hostinger website dashboard
2. Navigate to: Website → Advanced → GIT
3. Click "Connect with GitHub"
4. Authorize Hostinger to access your repositories
5. Select the `project-dashboard` repository
6. Select the `main` branch

### Step 5: Configure Deployment Settings

In Hostinger's deployment configuration:

**Build Command:**
```
npm run build --prefix frontend && npm install --prefix backend
```

**Start Command:**
```
node backend/server.js
```

**Environment Variables:**
Set the following environment variables in Hostinger:
```
NODE_ENV=production
PORT=3000
DB_TYPE=mysql
DB_HOST=<hostinger-db-host>
DB_USER=project_dashboard_user
DB_PASSWORD=<your-secure-password>
DB_NAME=project_dashboard
JWT_SECRET=<generate-a-random-secure-string>
CORS_ORIGIN=https://yourdomain.com
```

### Step 6: Connect Custom Domain

1. In Hostinger, go to Domain settings
2. Connect your custom domain (e.g., yourdomain.com)
3. Update DNS records if needed
4. SSL certificate will be auto-configured

### Step 7: Deploy

1. Push changes to the GitHub main branch:
```bash
git add .
git commit -m "Update for production"
git push origin main
```

2. Hostinger will automatically build and deploy

3. Monitor deployment status in Hostinger's Build & Deployment section

### Database Migration

The application automatically creates tables on first startup. No manual migration needed.

### Accessing Your Application

Once deployed:
- Frontend: https://yourdomain.com
- API: https://yourdomain.com/api
- Health check: https://yourdomain.com/health

### Troubleshooting

**"Database connection failed"**
- Verify DB_HOST, DB_USER, DB_PASSWORD in environment variables
- Check that MySQL database was created in Hostinger

**"Build failed"**
- Ensure both `backend/package.json` and `frontend/package.json` have correct dependencies
- Check that build command includes frontend build

**"Application crashes on startup"**
- Check Hostinger logs for errors
- Verify NODE_ENV is set to `production`
- Ensure JWT_SECRET is set

### Development vs Production

**Development (Local):**
- Uses SQLite database
- Hot reload enabled
- Uses .env.local file

**Production (Hostinger):**
- Uses MySQL database
- Environment variables set in Hostinger dashboard
- Automatic builds on git push

### Environment Variables Checklist

Before deploying, ensure these are set in Hostinger:
- [ ] NODE_ENV=production
- [ ] DB_TYPE=mysql
- [ ] DB_HOST (from Hostinger database details)
- [ ] DB_USER (from Hostinger database details)
- [ ] DB_PASSWORD (secure password)
- [ ] DB_NAME=project_dashboard
- [ ] JWT_SECRET (random secure string)
- [ ] CORS_ORIGIN (your domain)

### Monitoring

Monitor your application at:
- Hostinger Dashboard → Website Settings → Build & Deployment
- Check logs for errors
- Test API endpoints with curl or Postman

### Updating the Application

To update the production application:
1. Make changes locally
2. Commit and push to GitHub main branch
3. Hostinger automatically triggers a new build and deployment
4. Monitor the build process in the dashboard
