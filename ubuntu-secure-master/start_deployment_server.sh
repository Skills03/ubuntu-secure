#!/bin/bash
#
# Start Ubuntu Blockchain Deployment Server
# This creates the public endpoint that serves the one-command deploy script
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║        🌐 UBUNTU BLOCKCHAIN DEPLOYMENT SERVER 🌐                ║"
    echo "║                                                                  ║"
    echo "║      Serving one-command deployments to the world               ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

install_dependencies() {
    echo -e "${YELLOW}Installing dependencies...${NC}"

    # Install Python Flask if needed
    python3 -m pip install flask &>/dev/null || {
        sudo apt update && sudo apt install -y python3-pip python3-flask
    }

    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

get_public_access() {
    echo -e "${YELLOW}Setting up public access...${NC}"

    # Get local IP
    LOCAL_IP=$(hostname -I | awk '{print $1}')

    # Try to get public IP
    PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "")

    echo -e "${GREEN}✓ Local IP: $LOCAL_IP${NC}"
    if [[ -n "$PUBLIC_IP" ]]; then
        echo -e "${GREEN}✓ Public IP: $PUBLIC_IP${NC}"
    fi

    # Check if ngrok is available for instant public URL
    if command -v ngrok &> /dev/null; then
        echo -e "${YELLOW}Starting ngrok tunnel for public access...${NC}"
        ngrok http 5000 --log=stdout > ngrok.log 2>&1 &
        NGROK_PID=$!

        sleep 3

        # Get ngrok URL
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -Po '"public_url":"https://[^"]+' | cut -d'"' -f4 | head -1)

        if [[ -n "$NGROK_URL" ]]; then
            echo -e "${GREEN}✓ Public tunnel: $NGROK_URL${NC}"
            echo "$NGROK_URL" > public_url.txt
        fi
    fi
}

start_server() {
    echo -e "${YELLOW}Starting deployment server...${NC}"

    # Start the server
    python3 deployment_server.py &
    SERVER_PID=$!
    echo $SERVER_PID > server.pid

    sleep 3

    # Test if server is running
    if curl -s http://localhost:5000/health &>/dev/null; then
        echo -e "${GREEN}✓ Deployment server running (PID: $SERVER_PID)${NC}"
    else
        echo -e "${RED}✗ Server failed to start${NC}"
        exit 1
    fi
}

show_access_info() {
    echo
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    DEPLOYMENT SERVER READY                      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}🌍 Access URLs:${NC}"
    echo -e "   Local:      ${YELLOW}http://localhost:5000${NC}"

    if [[ -n "$LOCAL_IP" ]]; then
        echo -e "   LAN:        ${YELLOW}http://$LOCAL_IP:5000${NC}"
    fi

    if [[ -n "$PUBLIC_IP" ]]; then
        echo -e "   Public:     ${YELLOW}http://$PUBLIC_IP:5000${NC}"
    fi

    if [[ -f "public_url.txt" ]]; then
        NGROK_URL=$(cat public_url.txt)
        echo -e "   Tunnel:     ${YELLOW}$NGROK_URL${NC}"
    fi

    echo
    echo -e "${GREEN}🚀 One-Command Deploy:${NC}"

    if [[ -f "public_url.txt" ]]; then
        NGROK_URL=$(cat public_url.txt)
        echo -e "   ${YELLOW}curl -fsSL ${NGROK_URL}/deploy | bash${NC}"
    elif [[ -n "$PUBLIC_IP" ]]; then
        echo -e "   ${YELLOW}curl -fsSL http://$PUBLIC_IP:5000/deploy | bash${NC}"
    else
        echo -e "   ${YELLOW}curl -fsSL http://localhost:5000/deploy | bash${NC}"
    fi

    echo
    echo -e "${GREEN}📊 Endpoints:${NC}"
    echo -e "   /         - Landing page"
    echo -e "   /deploy   - Deployment script"
    echo -e "   /health   - Health check"
    echo -e "   /stats    - Statistics"
    echo -e "   /test     - Test deployment"
    echo
}

# Main execution
main() {
    print_banner
    install_dependencies
    get_public_access
    start_server
    show_access_info

    echo -e "${YELLOW}Server running... Press Ctrl+C to stop${NC}"
    echo

    # Keep script running and show logs
    tail -f deployment_server.log 2>/dev/null || {
        echo "Showing live requests..."
        while true; do
            sleep 1
        done
    }
}

# Cleanup on exit
cleanup() {
    echo
    echo -e "${YELLOW}Stopping server...${NC}"

    if [[ -f "server.pid" ]]; then
        kill $(cat server.pid) 2>/dev/null || true
        rm -f server.pid
    fi

    # Stop ngrok if running
    pkill ngrok 2>/dev/null || true

    echo -e "${GREEN}Server stopped${NC}"
}

trap cleanup EXIT INT TERM

# Start the server
main "$@"