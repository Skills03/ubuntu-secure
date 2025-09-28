#!/bin/bash

# Ubuntu Secure: Phase 1 Demonstration
# This script demonstrates the basic consensus mechanism for system calls

echo "=========================================="
echo " Ubuntu Secure: Distributed Consensus OS"
echo " Phase 1 - Basic Consensus Demonstration"
echo "=========================================="
echo ""

echo "[1] System Architecture:"
echo "    - Laptop (Primary viewport - potentially compromised)"
echo "    - Phone (ARM architecture)"
echo "    - Raspberry Pi (RISC-V architecture)"
echo "    - Cloud Instance (x86)"
echo "    - Friend's Device (Social trust validation)"
echo ""

echo "[2] Consensus Requirements:"
echo "    - 3/5 nodes must approve for consensus"
echo "    - Byzantine fault tolerance: 1 malicious node tolerated"
echo "    - Multi-architecture defense against exploits"
echo ""

echo "[3] Simulating System Call: open('/etc/passwd', O_RDWR)"
echo ""

# Simulate a critical system call requiring consensus
echo ">>> User attempts to open /etc/passwd for writing..."
echo ">>> System intercepts: SECURITY-CRITICAL operation detected!"
echo ">>> Creating blockchain transaction..."
echo ""

# Simulate voting from 5 nodes
echo "=== CONSENSUS VOTING IN PROGRESS ==="
echo ""

# Laptop (potentially compromised) - always approves its own requests
echo "Node 1 [Laptop/x86]:     APPROVE - Initiated by user"

# Phone validates based on security policy
echo "Node 2 [Phone/ARM]:      DENY    - Critical system file modification"

# Pi with conservative policy
echo "Node 3 [Pi/RISC-V]:      DENY    - No valid reason for /etc/passwd write"

# Cloud instance policy check
echo "Node 4 [Cloud/x86]:      DENY    - Violates security policy"

# Friend's device social validation
echo "Node 5 [Friend/Device]:  DENY    - User didn't mention system changes"

echo ""
echo "=== CONSENSUS RESULT ==="
echo "Votes FOR:     1/5"
echo "Votes AGAINST: 4/5"
echo "Threshold:     3/5 required"
echo ""
echo ">>> CONSENSUS: OPERATION DENIED <<<"
echo ">>> System call blocked by distributed consensus"
echo ""

echo "----------------------------------------"
echo ""

echo "[4] Simulating Legitimate Operation: open('/home/user/document.txt', O_RDWR)"
echo ""

echo ">>> User opens personal document..."
echo ">>> System intercepts: Standard file operation"
echo ">>> Creating blockchain transaction..."
echo ""

echo "=== CONSENSUS VOTING IN PROGRESS ==="
echo ""

echo "Node 1 [Laptop/x86]:     APPROVE - User initiated"
echo "Node 2 [Phone/ARM]:      APPROVE - Personal file, no security risk"
echo "Node 3 [Pi/RISC-V]:      APPROVE - Within user home directory"
echo "Node 4 [Cloud/x86]:      APPROVE - Normal user operation"
echo "Node 5 [Friend/Device]:  APPROVE - Expected user behavior"

echo ""
echo "=== CONSENSUS RESULT ==="
echo "Votes FOR:     5/5"
echo "Votes AGAINST: 0/5"
echo "Threshold:     3/5 required"
echo ""
echo ">>> CONSENSUS: OPERATION APPROVED <<<"
echo ">>> File opened successfully"
echo ""

echo "----------------------------------------"
echo ""

echo "[5] Attack Scenario: Intel ME Backdoor Attempt"
echo ""

echo ">>> Intel ME attempts rootkit installation..."
echo ">>> Laptop compromised at hardware level!"
echo ">>> Malicious transaction: modify_boot_sector()"
echo ""

echo "=== CONSENSUS VOTING IN PROGRESS ==="
echo ""

echo "Node 1 [Laptop/x86]:     APPROVE - [COMPROMISED]"
echo "Node 2 [Phone/ARM]:      DENY    - Unsigned boot modification detected"
echo "Node 3 [Pi/RISC-V]:      DENY    - Boot sector change without user action"
echo "Node 4 [Cloud/x86]:      DENY    - Critical security violation"
echo "Node 5 [Friend/Device]:  DENY    - Anomalous behavior detected"

echo ""
echo "=== CONSENSUS RESULT ==="
echo "Votes FOR:     1/5"
echo "Votes AGAINST: 4/5"
echo "Threshold:     3/5 required"
echo ""
echo ">>> CONSENSUS: ATTACK BLOCKED <<<"
echo ">>> Rootkit installation prevented despite hardware compromise"
echo ">>> Node 1 reputation decreased: 100 -> 98"
echo ""

echo "=========================================="
echo " Ubuntu Secure Status: OPERATIONAL"
echo " Security Level: NATION-STATE RESISTANT"
echo " Your laptop is compromised? So what."
echo " It's just 1 vote out of 5."
echo "=========================================="
echo ""

echo "Phase 1: Basic consensus mechanism ✓"
echo "Next: Phase 2 - System call transaction handling"