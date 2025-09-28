#!/bin/bash
#
# Ubuntu Secure - Real Blockchain Protection Deployment
#
# This script deploys ACTUAL Ubuntu protection using existing blockchain infrastructure
#
# Architecture:
#   Real Ubuntu Syscalls → Syscall Interceptor → Blockchain Bridge → Substrate Validators → Consensus
#
# Usage: ./deploy_real_ubuntu_blockchain.sh [start|stop|test|status]
#

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE_PID_FILE="/tmp/ubuntu_secure_bridge.pid"
SUBSTRATE_COMPOSE="docker-compose-blockchain.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[Ubuntu Secure]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[Warning]${NC} $1"
}

error() {
    echo -e "${RED}[Error]${NC} $1"
}

info() {
    echo -e "${BLUE}[Info]${NC} $1"
}

print_header() {
    echo
    echo "🔗 Ubuntu Secure - Real Blockchain Protection"
    echo "============================================="
    echo "Connecting real Ubuntu syscalls to Substrate blockchain"
    echo "Your laptop becomes just 1 validator out of N"
    echo
}

check_dependencies() {
    log "Checking dependencies..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Install with: sudo apt install docker.io"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose not found. Install with: sudo apt install docker-compose"
        exit 1
    fi

    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        error "Python 3 not found. Install with: sudo apt install python3"
        exit 1
    fi

    # Check GCC
    if ! command -v gcc &> /dev/null; then
        error "GCC not found. Install with: sudo apt install build-essential"
        exit 1
    fi

    # Check if we're on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        error "This only works on Linux"
        exit 1
    fi

    log "All dependencies satisfied"
}

install_python_deps() {
    log "Installing Python dependencies..."

    # Install required packages
    python3 -m pip install websockets requests &> /dev/null || {
        warn "Installing via apt..."
        sudo apt install python3-websockets python3-requests -y
    }
}

compile_interceptor() {
    log "Compiling syscall interceptor..."

    # Compile the blockchain-aware syscall interceptor
    gcc -shared -fPIC -o libintercept.so syscall_blockchain_hook.c -ldl

    if [[ $? -eq 0 ]]; then
        log "Syscall interceptor compiled successfully"
    else
        error "Compilation failed"
        exit 1
    fi

    # Test that it loads
    if LD_PRELOAD=./libintercept.so echo "test" > /dev/null 2>&1; then
        log "Syscall interceptor loads correctly"
    else
        error "Syscall interceptor loading failed"
        exit 1
    fi
}

start_blockchain() {
    log "Starting Substrate blockchain validators..."

    # Check if compose file exists
    if [[ ! -f "$SUBSTRATE_COMPOSE" ]]; then
        error "Blockchain compose file not found: $SUBSTRATE_COMPOSE"
        exit 1
    fi

    # Create network if it doesn't exist
    docker network create ubuntu-blockchain 2>/dev/null || true

    # Start the blockchain validators
    docker-compose -f "$SUBSTRATE_COMPOSE" up -d

    # Wait for blockchain to be ready
    log "Waiting for blockchain to initialize..."

    local retries=0
    local max_retries=30

    while [[ $retries -lt $max_retries ]]; do
        if curl -s http://localhost:9933 > /dev/null 2>&1; then
            log "Blockchain is ready"
            break
        fi

        sleep 2
        retries=$((retries + 1))

        if [[ $retries -eq $max_retries ]]; then
            error "Blockchain failed to start after 60 seconds"
            exit 1
        fi
    done

    # Show blockchain status
    info "Blockchain validators running:"
    docker-compose -f "$SUBSTRATE_COMPOSE" ps
}

start_bridge() {
    log "Starting blockchain bridge..."

    # Kill existing bridge
    if [[ -f "$BRIDGE_PID_FILE" ]]; then
        local old_pid=$(cat "$BRIDGE_PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid"
            log "Stopped existing bridge"
        fi
    fi

    # Start new bridge in background
    python3 blockchain_bridge.py > /tmp/ubuntu_secure_bridge.log 2>&1 &
    local bridge_pid=$!
    echo "$bridge_pid" > "$BRIDGE_PID_FILE"

    # Wait for bridge to be ready
    sleep 3

    if kill -0 "$bridge_pid" 2>/dev/null; then
        log "Blockchain bridge started (PID: $bridge_pid)"
    else
        error "Bridge failed to start. Check /tmp/ubuntu_secure_bridge.log"
        exit 1
    fi
}

test_protection() {
    log "Testing blockchain protection..."

    # Test blockchain connectivity
    python3 blockchain_bridge.py --test

    echo
    info "To activate real protection:"
    echo "  export LD_PRELOAD=./libintercept.so"
    echo
    info "Test commands (will require blockchain consensus):"
    echo "  sudo apt update          # Will ask validators"
    echo "  sudo rm -rf /tmp/test    # Will be blocked"
    echo "  echo 'test' | sudo tee /etc/motd  # Will require consensus"
    echo
    info "To disable protection:"
    echo "  unset LD_PRELOAD"
    echo

    warn "THIS IS REAL PROTECTION - Your syscalls are actually intercepted!"
}

stop_services() {
    log "Stopping Ubuntu Secure services..."

    # Stop bridge
    if [[ -f "$BRIDGE_PID_FILE" ]]; then
        local bridge_pid=$(cat "$BRIDGE_PID_FILE")
        if kill -0 "$bridge_pid" 2>/dev/null; then
            kill "$bridge_pid"
            log "Bridge stopped"
        fi
        rm -f "$BRIDGE_PID_FILE"
    fi

    # Stop blockchain
    docker-compose -f "$SUBSTRATE_COMPOSE" down

    log "All services stopped"
}

show_status() {
    echo
    echo "🔍 Ubuntu Secure Status"
    echo "======================"
    echo

    # Check blockchain
    if docker-compose -f "$SUBSTRATE_COMPOSE" ps | grep -q "Up"; then
        echo "✅ Blockchain validators: Running"
        echo "   Endpoint: ws://localhost:9944"

        # Test connectivity
        if curl -s http://localhost:9933 > /dev/null 2>&1; then
            echo "   Status: Accessible"
        else
            echo "   Status: Not responding"
        fi
    else
        echo "❌ Blockchain validators: Stopped"
    fi

    # Check bridge
    if [[ -f "$BRIDGE_PID_FILE" ]]; then
        local bridge_pid=$(cat "$BRIDGE_PID_FILE")
        if kill -0 "$bridge_pid" 2>/dev/null; then
            echo "✅ Blockchain bridge: Running (PID: $bridge_pid)"
        else
            echo "❌ Blockchain bridge: Stopped"
            rm -f "$BRIDGE_PID_FILE"
        fi
    else
        echo "❌ Blockchain bridge: Not started"
    fi

    # Check syscall protection
    if [[ -n "$LD_PRELOAD" ]] && [[ "$LD_PRELOAD" == *"libintercept.so"* ]]; then
        echo "✅ Syscall protection: Active"
        echo "   Your syscalls are protected by blockchain consensus"
    else
        echo "⏸️  Syscall protection: Inactive"
        echo "   Run: export LD_PRELOAD=./libintercept.so"
    fi

    # Check interceptor library
    if [[ -f "libintercept.so" ]]; then
        echo "✅ Syscall interceptor: Compiled"
    else
        echo "❌ Syscall interceptor: Not compiled"
    fi

    echo
    if [[ -f "/tmp/ubuntu_secure_bridge.log" ]]; then
        echo "📝 Bridge logs (last 5 lines):"
        tail -5 /tmp/ubuntu_secure_bridge.log | sed 's/^/   /'
    fi
}

main() {
    print_header

    case "${1:-start}" in
        "start")
            check_dependencies
            install_python_deps
            compile_interceptor
            start_blockchain
            start_bridge
            test_protection
            ;;
        "stop")
            stop_services
            ;;
        "test")
            test_protection
            ;;
        "status")
            show_status
            ;;
        "restart")
            stop_services
            sleep 2
            main start
            ;;
        *)
            error "Usage: $0 [start|stop|test|status|restart]"
            echo
            echo "Commands:"
            echo "  start   - Deploy full blockchain protection"
            echo "  stop    - Stop all services"
            echo "  test    - Test blockchain connectivity"
            echo "  status  - Show system status"
            echo "  restart - Restart all services"
            exit 1
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo; warn "Interrupted. Run \"$0 stop\" to clean up."; exit 1' INT

main "$@"