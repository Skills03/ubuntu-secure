#!/bin/bash
# Upload to NFT.Storage via API (permanent, free)

echo "🔗 Uploading Linux AS Blockchain to NFT.Storage..."
echo

FILE="linux-blockchain-sync.html"

# NFT.Storage public upload endpoint (no API key needed for small files)
# Using web3.storage public gateway

echo "📤 Uploading $FILE to Web3.Storage/NFT.Storage..."
echo

# Alternative: Use web3.storage CLI which is easier
if ! command -v w3 &> /dev/null; then
    echo "Installing web3.storage CLI..."
    npm install -g @web3-storage/w3cli
fi

echo "Uploading via web3.storage..."
w3 up "$FILE" --no-wrap

# Or show manual instructions
echo
echo "════════════════════════════════════════════════════════════"
echo "ALTERNATIVE: Manual Upload (2 minutes)"
echo "════════════════════════════════════════════════════════════"
echo
echo "1. Visit: https://nft.storage/login"
echo "2. Sign in with email or GitHub"
echo "3. Click 'Upload' button"
echo "4. Select: $FILE"
echo "5. Get IPFS CID"
echo
echo "Your file will be at:"
echo "   https://nft.storage/ipfs/<CID>"
echo "   https://ipfs.io/ipfs/<CID>"
echo
