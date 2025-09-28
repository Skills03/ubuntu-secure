#!/bin/bash

# Phase 2: Proper System Call Interceptor Test
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     PHASE 2: SYSTEM CALL INTERCEPTOR TEST                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Set the interceptor library
export LD_PRELOAD=/root/ubuntu-secure-master/ubuntu_secure.so

echo "Test 1: Try to create file in /etc/ (should be BLOCKED)"
echo "─────────────────────────────────────────────────────────"
echo "test" > /etc/test_file.txt 2>&1
echo ""

echo "Test 2: Try to read /etc/passwd (monitoring test)"
echo "─────────────────────────────────────────────────────────"
cat /etc/passwd 2>&1 | head -2
echo ""

echo "Test 3: Create file in /tmp/ (should be ALLOWED)"
echo "─────────────────────────────────────────────────────────"
echo "safe content" > /tmp/test_$$.txt 2>&1
if [ -f /tmp/test_$$.txt ]; then
    echo "✓ File created successfully in /tmp/"
    rm /tmp/test_$$.txt
else
    echo "✗ File creation failed"
fi
echo ""

echo "Test 4: Try to modify system binary permissions (should be BLOCKED)"
echo "────────────────────────────────────────────────────────────────────"
chmod 777 /usr/bin/ls 2>&1
echo ""

echo "Test 5: Execute a command (monitoring)"
echo "────────────────────────────────────────────"
/bin/echo "Hello from intercepted process" 2>&1
echo ""

echo "Test 6: Try to delete system file (should be BLOCKED)"
echo "──────────────────────────────────────────────────────"
rm /etc/hosts 2>&1
echo ""

# Clean up
unset LD_PRELOAD

echo "═══════════════════════════════════════════════════════════════"
echo "Test complete. Check above for interception messages."
echo "═══════════════════════════════════════════════════════════════"