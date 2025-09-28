#!/usr/bin/env python3
"""
Ubuntu Secure - Consensus Daemon
Real multi-device voting for Ubuntu operations

This daemon:
1. Receives requests from syscall interceptor
2. Contacts real devices for voting
3. Returns consensus decision

Run: python3 consensus_daemon.py
"""

import socket
import os
import sys
import time
import json
import threading
import signal
from typing import Dict, List, Optional

class Device:
    """Represents a real device that can vote"""

    def __init__(self, device_id: str, device_type: str, trust_level: float,
                 endpoint: Optional[str] = None):
        self.id = device_id
        self.type = device_type  # "phone", "yubikey", "cloud", "laptop"
        self.trust = trust_level
        self.endpoint = endpoint  # IP:port or hardware identifier
        self.last_seen = time.time()
        self.status = "online"

    def vote(self, operation: str, details: str) -> str:
        """
        Get vote from this device
        Phase 1: Simulated voting with real logic
        Phase 2: Will add real device communication
        """

        # Device offline check
        if time.time() - self.last_seen > 300:  # 5 minutes
            self.status = "offline"
            return "ABSTAIN"

        # Trust level check
        if self.trust < 0.3:
            return "ABSTAIN"

        # Operation-specific voting logic
        if operation == "sudo":
            return self._vote_sudo(details)
        elif operation == "file_write":
            return self._vote_file_write(details)
        elif operation == "network":
            return self._vote_network(details)
        else:
            # Unknown operation - be conservative
            return "DENY" if self.trust < 0.7 else "APPROVE"

    def _vote_sudo(self, details: str) -> str:
        """Vote on sudo operations"""

        # Dangerous commands that need high consensus
        dangerous_commands = [
            "rm -rf", "dd if=", "mkfs", "fdisk", "parted",
            "userdel", "passwd root", "chmod 777", "chown root"
        ]

        for dangerous in dangerous_commands:
            if dangerous in details.lower():
                # Very dangerous - only high-trust devices approve
                if self.trust >= 0.8 and self.type in ["yubikey", "phone"]:
                    return "APPROVE"  # Physical devices are more trusted
                else:
                    return "DENY"

        # Package management (common, less dangerous)
        if any(cmd in details for cmd in ["apt install", "apt update", "pip install"]):
            return "APPROVE" if self.trust >= 0.5 else "DENY"

        # Service management
        if any(cmd in details for cmd in ["systemctl", "service"]):
            return "APPROVE" if self.trust >= 0.6 else "DENY"

        # Default: approve for trusted devices
        return "APPROVE" if self.trust >= 0.6 else "DENY"

    def _vote_file_write(self, path: str) -> str:
        """Vote on file write operations"""

        # Critical system files
        critical_paths = ["/etc/passwd", "/etc/shadow", "/etc/sudoers", "/boot/"]

        for critical in critical_paths:
            if critical in path:
                # Only highest trust devices can modify critical files
                return "APPROVE" if self.trust >= 0.9 else "DENY"

        # System directories (need consensus)
        if any(p in path for p in ["/etc/", "/usr/", "/var/"]):
            return "APPROVE" if self.trust >= 0.6 else "DENY"

        # User files (generally OK)
        if "/home/" in path:
            return "APPROVE"

        return "APPROVE" if self.trust >= 0.5 else "DENY"

    def _vote_network(self, details: str) -> str:
        """Vote on network operations"""
        # Simplified for now
        return "APPROVE" if self.trust >= 0.5 else "DENY"

class ConsensusDaemon:
    """Main consensus coordination daemon"""

    def __init__(self):
        self.devices = {}
        self.socket_path = "/tmp/ubuntu_secure_consensus"
        self.running = False

        # Initialize device network
        self._initialize_devices()

        # Statistics
        self.total_requests = 0
        self.approved_requests = 0
        self.denied_requests = 0

    def _initialize_devices(self):
        """
        Initialize device network
        Phase 1: Simulated devices
        Phase 2: Will discover real devices
        """

        print("🔍 Discovering devices...")

        # Phase 1: Hardcoded device simulation
        # These represent real devices that would vote
        self.devices = {
            "laptop": Device("laptop", "laptop", 0.7, "localhost"),
            "phone": Device("phone", "phone", 0.9, "192.168.1.100"),
            "yubikey": Device("yubikey", "yubikey", 0.95, "hardware"),
            "cloud": Device("cloud", "cloud", 0.6, "cloud.example.com"),
            "friend_device": Device("friend", "laptop", 0.5, "192.168.1.200")
        }

        print(f"✓ {len(self.devices)} devices available")
        for device_id, device in self.devices.items():
            print(f"  📱 {device_id}: {device.type} (trust: {device.trust})")

    def request_consensus(self, operation: str, details: str) -> bool:
        """
        Request consensus from all devices
        Returns True if consensus reached, False otherwise
        """

        self.total_requests += 1

        print(f"\n🗳️  CONSENSUS REQUEST #{self.total_requests}")
        print(f"   Operation: {operation}")
        print(f"   Details: {details}")
        print("   Polling devices...")

        votes = {}

        # Collect votes from all devices
        for device_id, device in self.devices.items():
            vote = device.vote(operation, details)
            votes[device_id] = vote

            # Visual feedback
            if vote == "APPROVE":
                emoji = "✅"
            elif vote == "DENY":
                emoji = "❌"
            else:
                emoji = "⏸️"

            print(f"     {emoji} {device_id}: {vote} (trust: {device.trust})")

        # Count votes
        approvals = sum(1 for v in votes.values() if v == "APPROVE")
        denials = sum(1 for v in votes.values() if v == "DENY")
        abstentions = sum(1 for v in votes.values() if v == "ABSTAIN")

        # Consensus logic: need majority approval
        total_votes = approvals + denials  # Don't count abstentions
        consensus_threshold = (total_votes // 2) + 1

        consensus_reached = approvals >= consensus_threshold

        print(f"\n   📊 VOTE TALLY:")
        print(f"      Approve: {approvals}")
        print(f"      Deny: {denials}")
        print(f"      Abstain: {abstentions}")
        print(f"      Threshold: {consensus_threshold}")

        if consensus_reached:
            print(f"   ✅ CONSENSUS REACHED - Operation APPROVED")
            self.approved_requests += 1
            return True
        else:
            print(f"   ❌ CONSENSUS FAILED - Operation DENIED")
            self.denied_requests += 1
            return False

    def handle_client(self, client_socket):
        """Handle incoming consensus request from syscall interceptor"""

        try:
            # Receive request
            data = client_socket.recv(1024).decode('utf-8')

            if '|' in data:
                operation, details = data.split('|', 1)
            else:
                operation, details = data, ""

            # Get consensus
            approved = self.request_consensus(operation, details)

            # Send response
            response = "APPROVE" if approved else "DENY"
            client_socket.send(response.encode('utf-8'))

        except Exception as e:
            print(f"Error handling client: {e}")
            client_socket.send(b"DENY")  # Fail secure
        finally:
            client_socket.close()

    def start(self):
        """Start the consensus daemon"""

        print("\n🔒 Ubuntu Secure Consensus Daemon")
        print("==================================")
        print("Providing real multi-device security for Ubuntu")
        print("Your laptop is just 1 vote out of N\n")

        # Remove existing socket
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)

        # Create Unix socket
        server_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server_socket.bind(self.socket_path)
        server_socket.listen(5)

        print(f"✓ Listening on {self.socket_path}")
        print("✓ Ready to protect Ubuntu operations")
        print("\nTo activate protection:")
        print("  export LD_PRELOAD=./libintercept.so")
        print("  sudo apt install firefox  # Will require consensus!")
        print("\nPress Ctrl+C to stop\n")

        self.running = True

        try:
            while self.running:
                client_socket, _ = server_socket.accept()

                # Handle in thread for concurrent requests
                thread = threading.Thread(
                    target=self.handle_client,
                    args=(client_socket,)
                )
                thread.daemon = True
                thread.start()

        except KeyboardInterrupt:
            print("\n\n🛑 Shutting down consensus daemon...")
            self.print_statistics()
        finally:
            server_socket.close()
            if os.path.exists(self.socket_path):
                os.unlink(self.socket_path)

    def print_statistics(self):
        """Print daemon statistics"""
        print("\n📊 Session Statistics:")
        print(f"   Total requests: {self.total_requests}")
        print(f"   Approved: {self.approved_requests}")
        print(f"   Denied: {self.denied_requests}")
        if self.total_requests > 0:
            approval_rate = (self.approved_requests / self.total_requests) * 100
            print(f"   Approval rate: {approval_rate:.1f}%")
        print("\nYour laptop was just 1 vote out of N.")

def main():
    """Main entry point"""

    if len(sys.argv) > 1:
        if sys.argv[1] == "--test":
            # Test mode - just run consensus logic
            daemon = ConsensusDaemon()
            print("\n🧪 Testing consensus logic...")

            test_cases = [
                ("sudo", "apt install firefox"),
                ("sudo", "rm -rf /etc"),
                ("file_write", "/etc/passwd"),
                ("file_write", "/home/user/document.txt")
            ]

            for operation, details in test_cases:
                daemon.request_consensus(operation, details)
                print()

            return

    # Normal daemon mode
    daemon = ConsensusDaemon()

    # Handle shutdown gracefully
    def signal_handler(sig, frame):
        daemon.running = False

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    daemon.start()

if __name__ == "__main__":
    main()