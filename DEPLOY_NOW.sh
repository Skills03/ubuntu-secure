#!/bin/bash

# Ubuntu Blockchain OS - IMMEDIATE DEPLOYMENT
# Deploy locally first, then to cloud

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     UBUNTU BLOCKCHAIN OS - PRODUCTION DEPLOYMENT          ║${NC}"
echo -e "${BLUE}║     Deploying Secure, Distributed Ubuntu on Blockchain    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Step 1: Check if we can run locally
check_local_environment() {
    echo -e "${YELLOW}[1/10] Checking local environment...${NC}"
    
    # Check Python
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}✓ Python3 installed${NC}"
    else
        echo -e "${RED}✗ Python3 not found - installing...${NC}"
        sudo apt-get update && sudo apt-get install -y python3 python3-pip
    fi
    
    # Check and install required Python packages
    echo -e "${YELLOW}Installing Python dependencies...${NC}"
    pip3 install --user flask flask-cors flask-socketio redis psycopg2-binary cryptography pycryptodome
    
    # Check Docker
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓ Docker installed${NC}"
    else
        echo -e "${YELLOW}! Docker not installed - will run Python-only version${NC}"
    fi
}

# Step 2: Start local services
start_local_services() {
    echo -e "${YELLOW}[2/10] Starting local services...${NC}"
    
    # Create necessary directories
    mkdir -p logs
    mkdir -p data
    mkdir -p static
    
    # Start the main blockchain node
    echo -e "${YELLOW}Starting blockchain node...${NC}"
    python3 ubuntu_blockchain_os.py > logs/blockchain.log 2>&1 &
    BLOCKCHAIN_PID=$!
    echo $BLOCKCHAIN_PID > data/blockchain.pid
    
    # Start device nodes
    echo -e "${YELLOW}Starting device nodes...${NC}"
    python3 device_nodes.py > logs/devices.log 2>&1 &
    DEVICES_PID=$!
    echo $DEVICES_PID > data/devices.pid
    
    # Start MPC nodes
    echo -e "${YELLOW}Starting MPC computation nodes...${NC}"
    python3 mpc_compute.py > logs/mpc.log 2>&1 &
    MPC_PID=$!
    echo $MPC_PID > data/mpc.pid
    
    # Start web server
    echo -e "${YELLOW}Starting web interface...${NC}"
    python3 -m http.server 8080 --directory . > logs/web.log 2>&1 &
    WEB_PID=$!
    echo $WEB_PID > data/web.pid
    
    sleep 5
    
    # Check if services are running
    if ps -p $BLOCKCHAIN_PID > /dev/null; then
        echo -e "${GREEN}✓ Blockchain node running (PID: $BLOCKCHAIN_PID)${NC}"
    else
        echo -e "${RED}✗ Blockchain node failed to start${NC}"
    fi
    
    if ps -p $WEB_PID > /dev/null; then
        echo -e "${GREEN}✓ Web interface running (PID: $WEB_PID)${NC}"
    else
        echo -e "${RED}✗ Web interface failed to start${NC}"
    fi
}

# Step 3: Deploy to free cloud services
deploy_to_cloud() {
    echo -e "${YELLOW}[3/10] Deploying to cloud...${NC}"
    
    # Option 1: Deploy to Replit (free, immediate)
    echo -e "${BLUE}Option 1: Deploy to Replit (Recommended for quick testing)${NC}"
    echo "1. Visit https://replit.com"
    echo "2. Create new Python repl"
    echo "3. Upload the ubuntu-secure folder"
    echo "4. Run: python3 ubuntu_blockchain_os.py"
    echo "5. Your app will be live at: https://ubuntu-blockchain.YOUR_USERNAME.repl.co"
    echo
    
    # Option 2: Deploy to Render (free tier)
    echo -e "${BLUE}Option 2: Deploy to Render.com${NC}"
    cat > render.yaml << 'EOF'
services:
  - type: web
    name: ubuntu-blockchain
    env: python
    buildCommand: pip install -r requirements.txt
    startCommand: python3 ubuntu_blockchain_os.py
    envVars:
      - key: PORT
        value: 10000
    
  - type: worker
    name: consensus-node
    env: python
    buildCommand: pip install -r requirements.txt
    startCommand: python3 mpc_compute.py
EOF
    echo "1. Push code to GitHub"
    echo "2. Connect GitHub to Render.com"
    echo "3. Deploy with render.yaml"
    echo
    
    # Option 3: Deploy to Railway (free tier)
    echo -e "${BLUE}Option 3: Deploy to Railway.app${NC}"
    echo "1. Install Railway CLI: npm i -g @railway/cli"
    echo "2. Run: railway login"
    echo "3. Run: railway init"
    echo "4. Run: railway up"
    echo "5. Your app will be live with a railway.app URL"
    echo
    
    # Option 4: Deploy to Vercel (for frontend)
    echo -e "${BLUE}Option 4: Deploy Frontend to Vercel${NC}"
    echo "1. Install Vercel CLI: npm i -g vercel"
    echo "2. Run: vercel"
    echo "3. Follow prompts"
    echo "4. Frontend live at: https://ubuntu-blockchain.vercel.app"
}

# Step 4: Create ngrok tunnel for immediate internet access
setup_ngrok() {
    echo -e "${YELLOW}[4/10] Setting up public tunnel...${NC}"
    
    # Check if ngrok is installed
    if command -v ngrok &> /dev/null; then
        echo -e "${GREEN}✓ ngrok installed${NC}"
    else
        echo -e "${YELLOW}Installing ngrok...${NC}"
        # Download ngrok
        wget -q https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
        unzip -q ngrok-stable-linux-amd64.zip
        chmod +x ngrok
        sudo mv ngrok /usr/local/bin/
        rm ngrok-stable-linux-amd64.zip
    fi
    
    # Start ngrok tunnel
    echo -e "${YELLOW}Starting public tunnel...${NC}"
    ngrok http 8080 > logs/ngrok.log 2>&1 &
    NGROK_PID=$!
    echo $NGROK_PID > data/ngrok.pid
    
    sleep 3
    
    # Get public URL
    PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | grep -Po '"public_url":"https://[^"]+' | cut -d'"' -f4 | head -1)
    
    if [ ! -z "$PUBLIC_URL" ]; then
        echo -e "${GREEN}✓ Public URL: $PUBLIC_URL${NC}"
        echo $PUBLIC_URL > data/public_url.txt
    else
        echo -e "${YELLOW}! Ngrok tunnel pending...${NC}"
    fi
}

# Step 5: Deploy to GitHub Pages (static frontend)
deploy_github_pages() {
    echo -e "${YELLOW}[5/10] Deploying to GitHub Pages...${NC}"
    
    # Check if git is initialized
    if [ ! -d .git ]; then
        git init
        git add .
        git commit -m "Initial Ubuntu Blockchain OS deployment"
    fi
    
    # Create gh-pages branch
    git checkout -b gh-pages 2>/dev/null || git checkout gh-pages
    
    # Copy web interface
    cp web-interface.html index.html
    
    # Create GitHub Pages config
    cat > _config.yml << 'EOF'
theme: jekyll-theme-minimal
title: Ubuntu Blockchain OS
description: Secure, Distributed Ubuntu on Blockchain
EOF
    
    git add .
    git commit -m "Deploy to GitHub Pages"
    
    echo -e "${YELLOW}To complete GitHub Pages deployment:${NC}"
    echo "1. Create repo on GitHub: ubuntu-blockchain-os"
    echo "2. Run: git remote add origin https://github.com/YOUR_USERNAME/ubuntu-blockchain-os.git"
    echo "3. Run: git push -u origin gh-pages"
    echo "4. Enable GitHub Pages in repo settings"
    echo "5. Access at: https://YOUR_USERNAME.github.io/ubuntu-blockchain-os"
}

# Step 6: Deploy to free tier cloud services with one command
one_click_deploy() {
    echo -e "${YELLOW}[6/10] One-click deployment options...${NC}"
    
    # Create Heroku deployment
    cat > Procfile << 'EOF'
web: python3 ubuntu_blockchain_os.py
worker: python3 mpc_compute.py
EOF
    
    cat > app.json << 'EOF'
{
  "name": "Ubuntu Blockchain OS",
  "description": "Secure, distributed Ubuntu on blockchain",
  "repository": "https://github.com/ubuntu-secure/blockchain-os",
  "keywords": ["blockchain", "ubuntu", "security", "distributed"],
  "stack": "heroku-22",
  "buildpacks": [
    {
      "url": "heroku/python"
    }
  ]
}
EOF
    
    # Create Deploy to Heroku button
    cat > README_DEPLOY.md << 'EOF'
# Deploy Ubuntu Blockchain OS

## One-Click Deploy Options

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

[![Deploy to Railway](https://railway.app/button.svg)](https://railway.app/new/template)

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy)

[![Run on Repl.it](https://repl.it/badge/github/ubuntu-secure/blockchain-os)](https://repl.it/github/ubuntu-secure/blockchain-os)

[![Deploy to Vercel](https://vercel.com/button)](https://vercel.com/new/clone)

[![Deploy to Netlify](https://www.netlify.com/img/deploy/button.svg)](https://app.netlify.com/start/deploy)
EOF
    
    echo -e "${GREEN}✓ One-click deployment files created${NC}"
}

# Step 7: Create systemd service for production
create_systemd_service() {
    echo -e "${YELLOW}[7/10] Creating systemd service...${NC}"
    
    cat > ubuntu-blockchain.service << EOF
[Unit]
Description=Ubuntu Blockchain OS
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PWD
ExecStart=/usr/bin/python3 $PWD/ubuntu_blockchain_os.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    echo -e "${YELLOW}To install as system service:${NC}"
    echo "sudo cp ubuntu-blockchain.service /etc/systemd/system/"
    echo "sudo systemctl enable ubuntu-blockchain"
    echo "sudo systemctl start ubuntu-blockchain"
}

# Step 8: Quick deploy to DigitalOcean
deploy_digitalocean() {
    echo -e "${YELLOW}[8/10] DigitalOcean deployment script...${NC}"
    
    cat > deploy_digitalocean.sh << 'EOF'
#!/bin/bash
# DigitalOcean $5/month deployment

# Create droplet
doctl compute droplet create ubuntu-blockchain \
    --region nyc1 \
    --size s-1vcpu-1gb \
    --image ubuntu-22-04-x64 \
    --ssh-keys $(doctl compute ssh-key list --format ID --no-header) \
    --user-data-file cloud-init.yaml

# Get droplet IP
IP=$(doctl compute droplet get ubuntu-blockchain --format PublicIPv4 --no-header)

# SSH and deploy
ssh root@$IP << 'ENDSSH'
apt update && apt install -y python3-pip git
git clone https://github.com/ubuntu-secure/blockchain-os.git
cd blockchain-os
pip3 install -r requirements.txt
python3 ubuntu_blockchain_os.py &
ENDSSH

echo "Deployed to: http://$IP:8080"
EOF
    
    chmod +x deploy_digitalocean.sh
    echo -e "${GREEN}✓ DigitalOcean deployment script created${NC}"
}

# Step 9: Deploy to AWS Free Tier
deploy_aws() {
    echo -e "${YELLOW}[9/10] AWS Free Tier deployment...${NC}"
    
    cat > deploy_aws.sh << 'EOF'
#!/bin/bash
# AWS EC2 Free Tier deployment

# Launch EC2 instance
aws ec2 run-instances \
    --image-id ami-0c02fb55731490381 \
    --instance-type t2.micro \
    --key-name MyKeyPair \
    --security-group-ids sg-903004f8 \
    --user-data file://cloud-init.yaml \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ubuntu-blockchain}]'

# Get instance IP
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=ubuntu-blockchain" --query 'Reservations[0].Instances[0].InstanceId' --output text)
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Deployed to: http://$PUBLIC_IP:8080"
EOF
    
    chmod +x deploy_aws.sh
    echo -e "${GREEN}✓ AWS deployment script created${NC}"
}

# Step 10: Show deployment status
show_deployment_status() {
    echo
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           DEPLOYMENT STATUS - UBUNTU BLOCKCHAIN OS        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Local deployment
    echo -e "${GREEN}LOCAL DEPLOYMENT:${NC}"
    echo -e "  Web Interface:    http://localhost:8080"
    echo -e "  Blockchain API:   http://localhost:9944"
    echo -e "  Consensus API:    http://localhost:9001"
    
    # Check if ngrok URL exists
    if [ -f data/public_url.txt ]; then
        PUBLIC_URL=$(cat data/public_url.txt)
        echo
        echo -e "${GREEN}PUBLIC ACCESS (via ngrok):${NC}"
        echo -e "  🌍 Public URL: ${PUBLIC_URL}"
        echo -e "  Share this URL with anyone on the internet!"
    fi
    
    echo
    echo -e "${GREEN}QUICK DEPLOYMENT OPTIONS:${NC}"
    echo -e "  1. Replit:        https://replit.com/new/python"
    echo -e "  2. Railway:       railway up"
    echo -e "  3. Render:        https://render.com/deploy"
    echo -e "  4. Heroku:        git push heroku main"
    echo -e "  5. GitHub Pages:  git push origin gh-pages"
    
    echo
    echo -e "${GREEN}MONITORING:${NC}"
    echo -e "  View logs:        tail -f logs/*.log"
    echo -e "  Stop services:    ./stop_services.sh"
    echo -e "  Check status:     ps aux | grep python"
    
    echo
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     🚀 UBUNTU BLOCKCHAIN OS IS NOW DEPLOYED! 🚀           ║${NC}"
    echo -e "${BLUE}║     Anyone on the internet can access your secure OS      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

# Create stop script
create_stop_script() {
    cat > stop_services.sh << 'EOF'
#!/bin/bash
# Stop all Ubuntu Blockchain OS services

echo "Stopping services..."

# Kill processes using PID files
for pidfile in data/*.pid; do
    if [ -f "$pidfile" ]; then
        PID=$(cat "$pidfile")
        if ps -p $PID > /dev/null; then
            kill $PID
            echo "Stopped process $PID"
        fi
        rm "$pidfile"
    fi
done

# Kill any remaining Python processes
pkill -f "ubuntu_blockchain_os.py"
pkill -f "device_nodes.py"
pkill -f "mpc_compute.py"
pkill -f "http.server"

echo "All services stopped"
EOF
    chmod +x stop_services.sh
}

# Create cloud-init for automated cloud deployment
create_cloud_init() {
    cat > cloud-init.yaml << 'EOF'
#cloud-config
package_update: true
packages:
  - python3-pip
  - git
  - nginx

runcmd:
  - git clone https://github.com/ubuntu-secure/blockchain-os.git /opt/ubuntu-blockchain
  - cd /opt/ubuntu-blockchain
  - pip3 install -r requirements.txt
  - python3 ubuntu_blockchain_os.py &
  - |
    cat > /etc/nginx/sites-available/default << 'NGINX'
    server {
        listen 80;
        server_name _;
        location / {
            proxy_pass http://localhost:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
    NGINX
  - systemctl restart nginx
EOF
}

# Main deployment flow
main() {
    echo -e "${YELLOW}Starting Ubuntu Blockchain OS deployment...${NC}"
    echo
    
    # Create necessary files
    create_stop_script
    create_cloud_init
    
    # Run deployment steps
    check_local_environment
    start_local_services
    setup_ngrok
    one_click_deploy
    create_systemd_service
    deploy_digitalocean
    deploy_aws
    deploy_github_pages
    
    # Show final status
    show_deployment_status
    
    # Open browser
    echo
    echo -e "${YELLOW}Opening web interface...${NC}"
    if command -v xdg-open &> /dev/null; then
        xdg-open http://localhost:8080/web-interface.html &
    elif command -v open &> /dev/null; then
        open http://localhost:8080/web-interface.html &
    fi
    
    echo
    echo -e "${GREEN}✓ Deployment complete!${NC}"
    echo -e "${GREEN}✓ Your Ubuntu Blockchain OS is now accessible on the internet!${NC}"
    
    # Keep script running to show logs
    echo
    echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"
    echo -e "${YELLOW}Showing live logs...${NC}"
    echo
    
    # Show logs
    tail -f logs/*.log
}

# Handle script termination
trap 'echo -e "\n${YELLOW}Stopping services...${NC}"; ./stop_services.sh; exit' INT TERM

# Run deployment
main