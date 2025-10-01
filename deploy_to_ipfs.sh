#!/bin/bash
# Deploy Ubuntu Secure Web Terminal to IPFS (Decentralized Storage)
# This makes the web interface publicly accessible via IPFS

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  DEPLOYING TO IPFS - DECENTRALIZED STORAGE                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo

# Install IPFS if not present
if ! command -v ipfs &> /dev/null; then
    echo "📦 Installing IPFS (InterPlanetary File System)..."

    wget -q https://dist.ipfs.tech/kubo/v0.24.0/kubo_v0.24.0_linux-amd64.tar.gz
    tar -xzf kubo_v0.24.0_linux-amd64.tar.gz
    cd kubo
    sudo bash install.sh
    cd ..
    rm -rf kubo kubo_v0.24.0_linux-amd64.tar.gz

    echo "✅ IPFS installed"
fi

# Initialize IPFS
if [ ! -d ~/.ipfs ]; then
    echo "🔧 Initializing IPFS..."
    ipfs init
fi

# Start IPFS daemon in background
echo "🚀 Starting IPFS daemon..."
ipfs daemon > /tmp/ipfs.log 2>&1 &
IPFS_PID=$!
echo "   IPFS daemon PID: $IPFS_PID"
sleep 5

# Add web terminal to IPFS
echo "📤 Uploading web terminal to IPFS..."
IPFS_HASH=$(ipfs add -Q public_ubuntu_terminal.html)

echo
echo "════════════════════════════════════════════════════════════"
echo "✅ UPLOADED TO IPFS (DECENTRALIZED STORAGE)"
echo "════════════════════════════════════════════════════════════"
echo
echo "IPFS Hash: $IPFS_HASH"
echo
echo "🌐 PUBLIC ACCESS URLS (Anyone in the world can access):"
echo
echo "   https://ipfs.io/ipfs/$IPFS_HASH"
echo "   https://cloudflare-ipfs.com/ipfs/$IPFS_HASH"
echo "   https://dweb.link/ipfs/$IPFS_HASH"
echo "   https://gateway.pinata.cloud/ipfs/$IPFS_HASH"
echo
echo "════════════════════════════════════════════════════════════"
echo "✅ WEB TERMINAL NOW PUBLICLY ACCESSIBLE VIA IPFS"
echo "════════════════════════════════════════════════════════════"
echo
echo "📝 Next: Store this IPFS hash on Westend blockchain"
echo "   Run: node store_ipfs_on_blockchain.js $IPFS_HASH"
echo

# Save IPFS hash
echo "$IPFS_HASH" > ipfs_hash.txt
echo "💾 IPFS hash saved to: ipfs_hash.txt"
