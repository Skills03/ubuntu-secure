#!/bin/bash
# Deploy Ubuntu Secure to GitHub Pages (Free Public Hosting)

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  DEPLOYING TO GITHUB PAGES - PUBLIC HOSTING               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo

# Check if git repo
if [ ! -d .git ]; then
    echo "❌ Not a git repository"
    exit 1
fi

# Create docs folder for GitHub Pages
echo "📁 Creating docs folder for GitHub Pages..."
mkdir -p docs
cp public_ubuntu_terminal.html docs/index.html

echo "✅ Files prepared for GitHub Pages"
echo
echo "📝 Next: Push to GitHub and enable Pages"
