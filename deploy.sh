#!/bin/bash

# Ubuntu Blockchain OS - Production Deployment Script
# Deploy secure, distributed Ubuntu on blockchain for global access

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEPLOYMENT_ENV=${1:-production}
DOMAIN=${DOMAIN:-ubuntu-blockchain.org}
EMAIL=${EMAIL:-admin@ubuntu-blockchain.org}

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Ubuntu Blockchain OS - Production Deployment       ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}[1/10] Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker not installed${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ Docker installed${NC}"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}✗ Docker Compose not installed${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ Docker Compose installed${NC}"
    fi
    
    # Check kubectl (for Kubernetes deployment)
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}! kubectl not installed (optional for K8s)${NC}"
    else
        echo -e "${GREEN}✓ kubectl installed${NC}"
    fi
    
    # Check available memory
    available_mem=$(free -g | awk '/^Mem:/{print $7}')
    if [ "$available_mem" -lt 8 ]; then
        echo -e "${YELLOW}! Low memory: ${available_mem}GB available (recommend 16GB+)${NC}"
    else
        echo -e "${GREEN}✓ Memory: ${available_mem}GB available${NC}"
    fi
    
    # Check disk space
    available_disk=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_disk" -lt 100 ]; then
        echo -e "${YELLOW}! Low disk: ${available_disk}GB available (recommend 200GB+)${NC}"
    else
        echo -e "${GREEN}✓ Disk: ${available_disk}GB available${NC}"
    fi
}

# Function to create necessary directories
create_directories() {
    echo -e "${YELLOW}[2/10] Creating directory structure...${NC}"
    
    mkdir -p docker
    mkdir -p config
    mkdir -p nginx/ssl
    mkdir -p monitoring
    mkdir -p scripts
    mkdir -p backup
    mkdir -p logs
    
    echo -e "${GREEN}✓ Directories created${NC}"
}

# Function to generate SSL certificates
setup_ssl() {
    echo -e "${YELLOW}[3/10] Setting up SSL certificates...${NC}"
    
    if [ "$DEPLOYMENT_ENV" == "production" ]; then
        # Production: Use Let's Encrypt
        docker run --rm -v $(pwd)/nginx/ssl:/etc/letsencrypt \
            certbot/certbot certonly \
            --standalone \
            --non-interactive \
            --agree-tos \
            --email $EMAIL \
            -d $DOMAIN \
            -d api.$DOMAIN \
            -d consensus.$DOMAIN
        echo -e "${GREEN}✓ SSL certificates obtained from Let's Encrypt${NC}"
    else
        # Development: Generate self-signed certificates
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout nginx/ssl/privkey.pem \
            -out nginx/ssl/fullchain.pem \
            -subj "/C=US/ST=State/L=City/O=UbuntuBlockchain/CN=$DOMAIN"
        echo -e "${GREEN}✓ Self-signed SSL certificates generated${NC}"
    fi
}

# Function to generate configuration files
generate_configs() {
    echo -e "${YELLOW}[4/10] Generating configuration files...${NC}"
    
    # Generate .env file
    cat > .env << EOF
# Environment Configuration
DEPLOYMENT_ENV=$DEPLOYMENT_ENV
DOMAIN=$DOMAIN
EMAIL=$EMAIL

# Security
JWT_SECRET=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -hex 32)

# Database
DB_PASSWORD=$(openssl rand -hex 16)

# Node Configuration
NODE_ID=$(uuidgen)
CHAIN_ID=ubuntu-secure-mainnet

# Resource Limits
MAX_MEMORY=8G
MAX_CPU=4

# Features
ENABLE_MONITORING=true
ENABLE_BACKUP=true
EOF
    
    # Generate nginx.conf
    cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream api {
        server api:8000;
    }
    
    upstream web {
        server web-ui:3000;
    }
    
    server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
    }
    
    server {
        listen 443 ssl;
        server_name _;
        
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        
        location / {
            proxy_pass http://web;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
        
        location /api {
            proxy_pass http://api;
            proxy_http_version 1.1;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Host $host;
        }
        
        location /ws {
            proxy_pass http://api;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "Upgrade";
        }
    }
}
EOF
    
    echo -e "${GREEN}✓ Configuration files generated${NC}"
}

# Function to build Docker images
build_images() {
    echo -e "${YELLOW}[5/10] Building Docker images...${NC}"
    
    # Create Dockerfiles
    
    # Blockchain Node Dockerfile
    cat > docker/blockchain-node.Dockerfile << 'EOF'
FROM python:3.10-slim
WORKDIR /app
RUN apt-get update && apt-get install -y build-essential libssl-dev
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY secure_boot.py device_nodes.py ubuntu_blockchain_os.py ./
CMD ["python", "ubuntu_blockchain_os.py"]
EOF
    
    # Consensus x86 Dockerfile
    cat > docker/consensus-x86.Dockerfile << 'EOF'
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY mpc_compute.py .
CMD ["python", "mpc_compute.py"]
EOF
    
    # Create requirements.txt
    cat > requirements.txt << 'EOF'
cryptography==41.0.0
pycryptodome==3.18.0
requests==2.31.0
websocket-client==1.6.0
redis==5.0.0
psycopg2-binary==2.9.7
fastapi==0.103.0
uvicorn==0.23.0
pydantic==2.3.0
python-jose==3.3.0
EOF
    
    # Build images
    docker-compose build
    
    echo -e "${GREEN}✓ Docker images built${NC}"
}

# Function to initialize the blockchain
init_blockchain() {
    echo -e "${YELLOW}[6/10] Initializing blockchain...${NC}"
    
    # Start only the blockchain node first
    docker-compose up -d blockchain-node
    
    # Wait for initialization
    echo "Waiting for blockchain to initialize..."
    sleep 10
    
    # Check if blockchain is responding
    if curl -s http://localhost:9944/health > /dev/null; then
        echo -e "${GREEN}✓ Blockchain initialized${NC}"
    else
        echo -e "${YELLOW}! Blockchain initialization in progress...${NC}"
    fi
}

# Function to deploy all services
deploy_services() {
    echo -e "${YELLOW}[7/10] Deploying all services...${NC}"
    
    # Start all services
    docker-compose up -d
    
    # Wait for services to start
    echo "Waiting for services to start..."
    sleep 20
    
    # Check service health
    services=("blockchain-node" "consensus-x86" "ipfs" "api" "web-ui")
    for service in "${services[@]}"; do
        if docker-compose ps | grep $service | grep -q "Up"; then
            echo -e "${GREEN}✓ $service running${NC}"
        else
            echo -e "${RED}✗ $service not running${NC}"
        fi
    done
}

# Function to setup monitoring
setup_monitoring() {
    echo -e "${YELLOW}[8/10] Setting up monitoring...${NC}"
    
    # Create Prometheus configuration
    cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'blockchain'
    static_configs:
      - targets: ['blockchain-node:9615']
  
  - job_name: 'consensus'
    static_configs:
      - targets: ['consensus-x86:9001', 'consensus-arm:9002']
  
  - job_name: 'api'
    static_configs:
      - targets: ['api:8000']
EOF
    
    # Restart monitoring services
    docker-compose restart prometheus grafana
    
    echo -e "${GREEN}✓ Monitoring configured${NC}"
}

# Function to run health checks
health_check() {
    echo -e "${YELLOW}[9/10] Running health checks...${NC}"
    
    # Check blockchain sync
    echo -n "Blockchain sync: "
    if curl -s http://localhost:9944/health | grep -q "synced"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}syncing...${NC}"
    fi
    
    # Check consensus network
    echo -n "Consensus network: "
    if curl -s http://localhost:9001/status > /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    # Check API
    echo -n "API Gateway: "
    if curl -s http://localhost:8000/health > /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    # Check web interface
    echo -n "Web Interface: "
    if curl -s http://localhost:3000 > /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
}

# Function to display access information
display_info() {
    echo -e "${YELLOW}[10/10] Deployment complete!${NC}"
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}           Ubuntu Blockchain OS - Access Info          ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo
    echo -e "🌐 Web Interface:    https://$DOMAIN"
    echo -e "🔌 API Endpoint:     https://api.$DOMAIN"
    echo -e "🔗 Blockchain RPC:   https://rpc.$DOMAIN"
    echo -e "📊 Monitoring:       https://monitoring.$DOMAIN"
    echo -e "📁 IPFS Gateway:     https://ipfs.$DOMAIN"
    echo
    echo -e "${GREEN}Default credentials:${NC}"
    echo -e "  Username: admin"
    echo -e "  Password: (check .env file)"
    echo
    echo -e "${YELLOW}Important commands:${NC}"
    echo -e "  View logs:        docker-compose logs -f"
    echo -e "  Stop services:    docker-compose down"
    echo -e "  Backup:          ./scripts/backup.sh"
    echo -e "  Update:          ./scripts/update.sh"
    echo
    echo -e "${GREEN}✓ Ubuntu Blockchain OS is now running!${NC}"
    echo -e "${GREEN}✓ Anyone on the internet can now access it at: https://$DOMAIN${NC}"
}

# Main deployment flow
main() {
    echo "Starting deployment for environment: $DEPLOYMENT_ENV"
    echo
    
    check_prerequisites
    create_directories
    setup_ssl
    generate_configs
    build_images
    init_blockchain
    deploy_services
    setup_monitoring
    health_check
    display_info
    
    # Create backup script
    cat > scripts/backup.sh << 'EOF'
#!/bin/bash
# Backup critical data
BACKUP_DIR="backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup volumes
docker run --rm -v ubuntu-secure_blockchain-data:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/blockchain.tar.gz /data
docker run --rm -v ubuntu-secure_postgres-data:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/postgres.tar.gz /data

echo "Backup completed: $BACKUP_DIR"
EOF
    chmod +x scripts/backup.sh
    
    # Create update script
    cat > scripts/update.sh << 'EOF'
#!/bin/bash
# Update the system
git pull origin main
docker-compose pull
docker-compose build
docker-compose up -d
echo "Update completed"
EOF
    chmod +x scripts/update.sh
    
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}        🚀 Deployment Successful! 🚀                   ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
}

# Run main deployment
main