#!/bin/bash
#
# Ubuntu Secure - Start Blockchain
# Simple one-command deployment following development methodology
#

echo "========================================"
echo "UBUNTU SECURE ON POLKADOT"
echo "========================================"
echo

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    echo "Install Docker: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# Start containers
echo "Starting Substrate blockchain and web interface..."
docker compose -f docker-compose-final.yml up -d

# Wait for Substrate to be ready
echo "Waiting for blockchain to initialize..."
sleep 5

# Check if running
if docker ps | grep -q ubuntu-substrate; then
    echo
    echo "✅ SUCCESS - Ubuntu Secure is running!"
    echo
    echo "Access points:"
    echo "  🌐 Web Interface:  http://localhost:8080"
    echo "  ⛓️  Blockchain RPC: ws://localhost:9944"
    echo "  📡 HTTP RPC:       http://localhost:9933"
    echo
    echo "Test the system:"
    echo "  1. Open http://localhost:8080 in your browser"
    echo "  2. Click 'Request Boot' to test consensus"
    echo "  3. Watch the blockchain process operations"
    echo
    echo "View logs:"
    echo "  docker logs ubuntu-substrate -f"
    echo
    echo "Stop the system:"
    echo "  docker compose -f docker-compose-final.yml down"
    echo
else
    echo "Error: Failed to start. Check Docker logs:"
    echo "  docker compose -f docker-compose-final.yml logs"
fi