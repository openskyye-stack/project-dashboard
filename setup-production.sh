#!/bin/bash

# Project Dashboard Production Setup Script

echo "=== Project Dashboard Production Setup ==="
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

echo "✓ Node.js is installed: $(node --version)"

# Install backend dependencies
echo ""
echo "📦 Installing backend dependencies..."
cd backend
npm install
if [ $? -eq 0 ]; then
    echo "✓ Backend dependencies installed"
else
    echo "❌ Failed to install backend dependencies"
    exit 1
fi

# Install frontend dependencies
echo ""
echo "📦 Installing frontend dependencies..."
cd ../frontend
npm install
if [ $? -eq 0 ]; then
    echo "✓ Frontend dependencies installed"
else
    echo "❌ Failed to install frontend dependencies"
    exit 1
fi

# Build frontend
echo ""
echo "🔨 Building frontend for production..."
npm run build
if [ $? -eq 0 ]; then
    echo "✓ Frontend built successfully"
    echo "  Built files are in: frontend/dist/"
else
    echo "❌ Failed to build frontend"
    exit 1
fi

cd ..

# Check for environment files
echo ""
echo "📋 Environment Configuration:"
if [ -f "backend/.env" ]; then
    echo "✓ Backend .env file exists"
else
    echo "⚠️  Backend .env file not found"
    echo "   Please copy backend/.env.example to backend/.env"
    echo "   and update with your database credentials"
fi

if [ -f "frontend/.env" ]; then
    echo "✓ Frontend .env file exists"
else
    echo "⚠️  Frontend .env file not found"
    echo "   Please copy frontend/.env.example to frontend/.env"
fi

# Summary
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Update environment files with production values"
echo "2. Set up MySQL database on your hosting provider"
echo "3. Initialize Git repository (git init)"
echo "4. Push code to GitHub"
echo "5. Configure deployment on Hostinger"
echo ""
echo "See DEPLOYMENT.md for detailed instructions"
