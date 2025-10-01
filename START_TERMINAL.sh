#!/bin/bash
# Start Ubuntu Secure Blockchain Terminal

echo "🔗 Starting Ubuntu Secure - Blockchain Terminal"
echo "================================================"
echo

# Start terminal server
echo "▶️  Starting terminal server..."
node ubuntu-blockchain-terminal-server.js > /tmp/terminal_server.log 2>&1 &
SERVER_PID=$!

sleep 3

if ps -p $SERVER_PID > /dev/null; then
    echo "✅ Terminal server running (PID: $SERVER_PID)"
    echo
    echo "🌐 ACCESS TERMINAL:"
    echo "   Local:   http://localhost:3000/ubuntu-blockchain-terminal.html"
    echo "   Network: http://$(hostname -I | awk '{print $1}'):3000/ubuntu-blockchain-terminal.html"
    echo
    echo "🔗 Blockchain: Westend Testnet (Block #27935116)"
    echo "🔒 Consensus: Active"
    echo
    echo "📖 Press Ctrl+C to stop server"
    echo
    
    # Keep running
    tail -f /tmp/terminal_server.log
else
    echo "❌ Failed to start server"
    cat /tmp/terminal_server.log
    exit 1
fi
