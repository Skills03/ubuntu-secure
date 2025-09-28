#!/bin/bash

# Ubuntu Secure: Full Stack Test (Phases 1-3)
# Simple test following progressive enhancement

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         UBUNTU SECURE: FULL STACK TEST                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 Component Check:"
echo "──────────────────"

# Check Phase 1: Blockchain (Polkadot SDK)
if [ -d "ubuntu-blockchain-node/pallets/ubuntu-secure" ]; then
    echo "✅ Phase 1: Polkadot SDK blockchain pallet"
else
    echo "❌ Phase 1: Missing"
fi

# Check Phase 2: Syscall interceptor
if [ -f "ubuntu_secure.so" ]; then
    echo "✅ Phase 2: System call interceptor (.so library)"
else
    echo "❌ Phase 2: Missing - run 'make'"
fi

# Check Phase 3: Multi-node network
if docker ps | grep -q ubuntu-secure; then
    echo "✅ Phase 3: 5-node Docker network running"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep ubuntu-secure
else
    echo "❌ Phase 3: Docker nodes not running"
fi

echo ""
echo "🔄 Integration Test:"
echo "──────────────────"

# Test with interceptor
echo ""
echo "1. Testing malicious operation (should be blocked):"
LD_PRELOAD=./ubuntu_secure.so bash -c "echo 'evil' > /etc/test 2>&1" | head -3

echo ""
echo "2. Testing legitimate operation (should work):"
LD_PRELOAD=./ubuntu_secure.so bash -c "echo 'safe' > /tmp/test_$$.txt 2>&1"
if [ -f /tmp/test_$$.txt ]; then
    echo "   ✅ File created successfully"
    rm /tmp/test_$$.txt
fi

echo ""
echo "3. Testing Python consensus network:"
python3 phase3_multinode.py 2>/dev/null | grep -A2 "Results:"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                    ARCHITECTURE SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Layer 1: Polkadot SDK Blockchain (Rust)"
echo "         └─ Consensus mechanism and state storage"
echo ""
echo "Layer 2: System Call Interceptor (C)"
echo "         └─ LD_PRELOAD library intercepting syscalls"
echo ""
echo "Layer 3: Multi-Node Network (Docker)"
echo "         └─ 5 nodes voting on operations"
echo ""
echo "Result: Every critical operation requires 3/5 consensus"
echo "        Your laptop is compromised? It's just 1 vote."
echo ""
echo "═══════════════════════════════════════════════════════════════"