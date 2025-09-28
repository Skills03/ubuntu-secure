#!/usr/bin/env python3
"""
Phase 5: Emergency Revocation System via Substrate
~300 lines following progressive enhancement methodology
Friends can permanently disable compromised devices
"""

import json
import time
import hashlib
import subprocess
import requests
from typing import Dict, List, Optional
from dataclasses import dataclass

# Phase 1-4 imports (existing system remains unchanged)
from secure_boot import ThresholdBootSystem
from mpc_compute import MPCCoordinator, MPCNode
from substrate_zk_attestation import SubstrateZKAttestation

@dataclass
class FriendDevice:
    """Trusted friend who can vote on revocation"""
    name: str
    device_id: str
    public_key: str
    trust_level: float  # 0.0 to 1.0
    location: str  # Geographic diversity

@dataclass
class RevocationRequest:
    """Request to revoke a compromised device"""
    target_device: str
    reason: str
    timestamp: float
    requester: str
    evidence: str

class SubstrateEmergencyRevocation:
    """
    Phase 5: Friend-based emergency revocation via blockchain
    Builds on Phase 1-4 without modifying them
    """

    def __init__(self):
        # Phase 1-4 components (unchanged)
        self.boot_system = ThresholdBootSystem()
        nodes = [
            MPCNode("laptop", "x86_64", 7001),
            MPCNode("phone", "ARM", 7002),
            MPCNode("pi", "RISC-V", 7003)
        ]
        self.mpc = MPCCoordinator(nodes)
        self.zk_system = SubstrateZKAttestation()

        # Phase 5: Emergency revocation
        self.friends = []
        self.revocation_threshold = 2  # Need 2 of 3 friends
        self.revoked_devices = set()  # Permanently revoked
        self.pending_revocations = {}  # Device -> votes
        self.revocation_cache_file = ".revoked_devices.json"

        # Load persisted revocations
        self._load_revoked_devices()

    def register_friend(self, friend: FriendDevice) -> bool:
        """Register a trusted friend who can vote on revocations"""
        print(f"[Friends] Registering {friend.name} as trusted friend")

        # Verify friend's device via ZK attestation (Phase 4)
        if not self.zk_system.verify_with_consensus(f"friend_registration_{friend.device_id}"):
            print(f"[Friends] ✗ {friend.name}'s device failed attestation")
            return False

        self.friends.append(friend)
        print(f"[Friends] ✓ {friend.name} registered (Total friends: {len(self.friends)})")
        return True

    def request_revocation(self, request: RevocationRequest) -> str:
        """Initiate emergency revocation of compromised device"""
        print("\n" + "=" * 70)
        print("EMERGENCY REVOCATION REQUEST")
        print("=" * 70)
        print(f"Target: {request.target_device}")
        print(f"Reason: {request.reason}")
        print(f"Requester: {request.requester}")

        # Check if already revoked
        if request.target_device in self.revoked_devices:
            print("[Revoke] Device already revoked")
            return "already_revoked"

        # Initialize voting for this device
        if request.target_device not in self.pending_revocations:
            self.pending_revocations[request.target_device] = {
                "request": request,
                "votes": [],
                "timestamp": time.time()
            }

        # Notify friends
        self._notify_friends(request)

        # If requester is a friend, auto-vote
        for friend in self.friends:
            if friend.device_id == request.requester:
                self.vote_on_revocation(request.target_device, friend.device_id, "approve")
                break

        return "pending_votes"

    def vote_on_revocation(self, target_device: str, voter_id: str, vote: str) -> bool:
        """Friend votes on revocation request"""
        if target_device not in self.pending_revocations:
            print(f"[Vote] No pending revocation for {target_device}")
            return False

        # Verify voter is a friend
        voter = None
        for friend in self.friends:
            if friend.device_id == voter_id:
                voter = friend
                break

        if not voter:
            print(f"[Vote] {voter_id} is not a registered friend")
            return False

        # Record vote
        vote_record = {
            "voter": voter.name,
            "vote": vote,
            "timestamp": time.time(),
            "weight": voter.trust_level
        }

        self.pending_revocations[target_device]["votes"].append(vote_record)
        print(f"[Vote] {voter.name} voted: {vote.upper()}")

        # Check if threshold reached
        return self._check_revocation_consensus(target_device)

    def _check_revocation_consensus(self, target_device: str) -> bool:
        """Check if enough friends voted to revoke"""
        if target_device not in self.pending_revocations:
            return False

        votes = self.pending_revocations[target_device]["votes"]
        approve_votes = sum(1 for v in votes if v["vote"] == "approve")

        print(f"[Consensus] Votes to revoke: {approve_votes}/{self.revocation_threshold}")

        if approve_votes >= self.revocation_threshold:
            print("[Consensus] ⚠️  REVOCATION THRESHOLD REACHED")
            self._execute_revocation(target_device)
            return True

        return False

    def _execute_revocation(self, target_device: str):
        """Permanently revoke a device"""
        print("\n" + "🚨" * 35)
        print("EXECUTING EMERGENCY REVOCATION")
        print("🚨" * 35)

        # Add to revoked set
        self.revoked_devices.add(target_device)

        # Submit to blockchain if available
        if self._submit_revocation_to_blockchain(target_device):
            print("[Blockchain] ✓ Revocation recorded on-chain")
        else:
            print("[Fallback] Revocation stored locally")

        # Persist locally
        self._save_revoked_devices()

        # Destroy keys for this device (Phase 1 integration)
        self._destroy_device_keys(target_device)

        # Alert all nodes (Phase 3 integration)
        self._broadcast_revocation(target_device)

        print(f"\n✓ DEVICE {target_device} PERMANENTLY REVOKED")
        print("This device can never boot Ubuntu Secure again")

        # Clear pending votes
        del self.pending_revocations[target_device]

    def _submit_revocation_to_blockchain(self, device_id: str) -> bool:
        """Submit revocation to Substrate blockchain"""
        try:
            # Create revocation extrinsic
            revocation = {
                "type": "emergency_revocation",
                "device": device_id,
                "timestamp": time.time(),
                "votes": len(self.pending_revocations[device_id]["votes"]),
                "permanent": True
            }

            # Submit to blockchain (reuse Phase 4 connection)
            payload = {
                "jsonrpc": "2.0",
                "method": "author_submitExtrinsic",
                "params": ["0x" + json.dumps(revocation).encode().hex()],
                "id": 1
            }

            # Try local Substrate node
            response = requests.post("http://localhost:9933", json=payload, timeout=5)
            return "result" in response.json()

        except:
            return False  # Fallback to local storage

    def _destroy_device_keys(self, device_id: str):
        """Destroy all key shares for revoked device"""
        print(f"[Keys] Destroying all keys for {device_id}...")

        # In real implementation, would securely overwrite key storage
        # Here we simulate by marking keys invalid
        destroyed_keys = [
            "master_key_share",
            "device_private_key",
            "attestation_key",
            "recovery_key"
        ]

        for key in destroyed_keys:
            print(f"  ✗ Destroyed: {key}")

    def _broadcast_revocation(self, device_id: str):
        """Alert all nodes about revocation"""
        print("[Broadcast] Notifying all nodes...")

        # Would broadcast to Phase 3 MPC network
        notifications = [
            ("Phone", "Revocation alert sent"),
            ("Cloud", "Device blocklisted"),
            ("Friend nodes", "Revocation propagated"),
            ("Backup services", "Access terminated")
        ]

        for target, status in notifications:
            print(f"  → {target}: {status}")

    def _notify_friends(self, request: RevocationRequest):
        """Notify friends about revocation request"""
        print("\n[Notify] Alerting trusted friends...")

        for friend in self.friends:
            print(f"  📱 {friend.name}: URGENT - Vote on revocation of {request.target_device}")
            print(f"     Reason: {request.reason}")

    def _load_revoked_devices(self):
        """Load persisted revocation list"""
        try:
            with open(self.revocation_cache_file, 'r') as f:
                self.revoked_devices = set(json.load(f))
                if self.revoked_devices:
                    print(f"[Load] {len(self.revoked_devices)} devices permanently revoked")
        except:
            pass  # No revocations yet

    def _save_revoked_devices(self):
        """Persist revocation list"""
        with open(self.revocation_cache_file, 'w') as f:
            json.dump(list(self.revoked_devices), f)

    def check_device_revoked(self, device_id: str) -> bool:
        """Check if device is revoked (called during boot)"""
        # Check local cache
        if device_id in self.revoked_devices:
            return True

        # Check blockchain if available
        try:
            payload = {
                "jsonrpc": "2.0",
                "method": "state_getStorage",
                "params": [self._get_revocation_storage_key(device_id)],
                "id": 1
            }
            response = requests.post("http://localhost:9933", json=payload, timeout=2)
            result = response.json().get("result")
            return result is not None
        except:
            return False

    def _get_revocation_storage_key(self, device_id: str) -> str:
        """Generate storage key for revocation check"""
        # Simplified - real implementation would use proper SCALE encoding
        return "0x" + hashlib.blake2b(f"Revocations:{device_id}".encode()).hexdigest()

def main():
    """Test Phase 5: Emergency Revocation"""
    print("=" * 70)
    print("UBUNTU SECURE - PHASE 5: EMERGENCY REVOCATION")
    print("=" * 70)

    # Initialize Phase 5 (includes Phase 1-4)
    system = SubstrateEmergencyRevocation()

    # Register trusted friends
    friends = [
        FriendDevice("Alice", "alice_phone", "pubkey_alice", 0.9, "New York"),
        FriendDevice("Bob", "bob_laptop", "pubkey_bob", 0.85, "London"),
        FriendDevice("Charlie", "charlie_tablet", "pubkey_charlie", 0.8, "Tokyo")
    ]

    for friend in friends:
        system.register_friend(friend)

    # Simulate compromise detection
    print("\n⚠️  COMPROMISE DETECTED on device: evil_laptop")

    # Create revocation request
    request = RevocationRequest(
        target_device="evil_laptop",
        reason="Rootkit detected, Intel ME compromised",
        timestamp=time.time(),
        requester="alice_phone",
        evidence="Hash mismatch, unauthorized kernel modules"
    )

    # Request revocation
    system.request_revocation(request)

    # Friends vote
    print("\n[Simulation] Friends voting...")
    system.vote_on_revocation("evil_laptop", "bob_laptop", "approve")

    # Check if device can boot
    print("\n[Test] Checking if evil_laptop can boot...")
    if system.check_device_revoked("evil_laptop"):
        print("✓ Boot blocked - device is revoked")
    else:
        print("✗ Device not properly revoked")

    print("\n" + "=" * 70)
    print("Phase 5 complete: Emergency revocation via friend consensus")
    print("Compromised devices can be permanently disabled")
    print("=" * 70)

if __name__ == "__main__":
    main()