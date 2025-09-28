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
