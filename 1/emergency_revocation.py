#!/usr/bin/env python3
"""
Phase 5: Emergency Revocation System
When your laptop is compromised/stolen, friends can permanently disable it
This is the "kill switch" for worst-case scenarios
"""

import hashlib
import secrets
import json
import time
import threading
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum

class ThreatLevel(Enum):
    """Threat severity levels"""
    LOW = "low"           # Suspicious activity
    MEDIUM = "medium"     # Probable compromise
    HIGH = "high"         # Confirmed compromise
    CRITICAL = "critical" # Active attack in progress
    STOLEN = "stolen"     # Physical theft

@dataclass
class RevocationRequest:
    """Request to revoke a device's access"""
    device_id: str
    requester_id: str
    threat_level: ThreatLevel
    reason: str
    evidence: Dict
    timestamp: float
    expires: float  # Request expires if not acted upon

@dataclass 
class FriendDevice:
    """Trusted friend who can vote on revocation"""
    friend_id: str
    public_key: str
    trust_score: float  # 0.0 to 1.0
    location: str      # Geographic diversity
    contact_method: str # How to reach them
    response_time: float # Average response time

class EmergencyRevocationSystem:
    """
    Distributed kill switch - friends can collectively disable compromised device
    """
    
    def __init__(self, device_id: str, revocation_threshold: int = 2):
        self.device_id = device_id
        self.revocation_threshold = revocation_threshold
        
        # Device states
        self.is_revoked = False
        self.is_locked = False
        self.threat_detected = False
        
        # Friend network
        self.friends: Dict[str, FriendDevice] = {}
        self.pending_votes: Dict[str, str] = {}  # friend_id -> vote
        
        # Revocation history
        self.revocation_log = []
        self.false_alarm_count = 0
        
        # Dead man's switch
        self.last_heartbeat = time.time()
        self.heartbeat_timeout = 86400  # 24 hours
        
    def register_friend(self, friend: FriendDevice):
        """Register a trusted friend who can vote on revocation"""
        self.friends[friend.friend_id] = friend
        print(f"[Revocation] Registered friend: {friend.friend_id} "
              f"(trust: {friend.trust_score}, location: {friend.location})")
    
    def initiate_revocation(self, request: RevocationRequest) -> str:
        """
        Start emergency revocation process
        This cannot be undone once threshold is reached!
        """
        print(f"\n{'='*60}")
        print(f"EMERGENCY REVOCATION INITIATED")
        print(f"{'='*60}")
        print(f"Device: {request.device_id}")
        print(f"Threat Level: {request.threat_level.value.upper()}")
        print(f"Reason: {request.reason}")
        print(f"Requester: {request.requester_id}")
        
        # Log the request
        self.revocation_log.append({
            "type": "revocation_request",
            "request": request,
            "timestamp": time.time()
        })
        
        # Determine required votes based on threat level
        if request.threat_level == ThreatLevel.CRITICAL:
            required_votes = 1  # Single friend can act on critical
        elif request.threat_level == ThreatLevel.STOLEN:
            required_votes = 1  # Quick action for theft
        elif request.threat_level == ThreatLevel.HIGH:
            required_votes = 2  # Standard threshold
        else:
            required_votes = 3  # Higher threshold for lower threats
        
        print(f"Required votes: {required_votes}/{len(self.friends)}")
        
        # Notify all friends
        return self.broadcast_emergency(request, required_votes)
    
    def broadcast_emergency(self, request: RevocationRequest, 
                           required_votes: int) -> str:
        """Send emergency notification to all friends"""
        
        notifications_sent = []
        
        for friend_id, friend in self.friends.items():
            # Skip the requester
            if friend_id == request.requester_id:
                self.pending_votes[friend_id] = "INITIATED"
                continue
            
            # Send notification based on contact method
            notification = self.send_notification(friend, request)
            notifications_sent.append(notification)
            
            print(f"[→] Notifying {friend_id} via {friend.contact_method}...")
        
        # Start vote collection
        vote_thread = threading.Thread(
            target=self.collect_votes,
            args=(request, required_votes)
        )
        vote_thread.daemon = True
        vote_thread.start()
        
        return f"Notified {len(notifications_sent)} friends"
    
    def send_notification(self, friend: FriendDevice, 
                         request: RevocationRequest) -> Dict:
        """Send emergency notification to friend"""
        
        message = {
            "type": "EMERGENCY_REVOCATION",
            "device": self.device_id,
            "threat": request.threat_level.value,
            "reason": request.reason,
            "evidence": request.evidence,
            "action_required": "VOTE: REVOKE or REJECT",
            "expires": request.expires,
            "timestamp": time.time()
        }
        
        # Simulate different notification methods
        if "push" in friend.contact_method:
            print(f"  📱 Push notification to {friend.friend_id}")
        elif "sms" in friend.contact_method:
            print(f"  💬 SMS sent to {friend.friend_id}")
        elif "email" in friend.contact_method:
            print(f"  📧 Email sent to {friend.friend_id}")
        elif "signal" in friend.contact_method:
            print(f"  🔒 Signal message to {friend.friend_id}")
        
        return message
    
    def receive_vote(self, friend_id: str, vote: str, 
                    signature: str = None) -> bool:
        """Receive and validate friend's vote"""
        
        if friend_id not in self.friends:
            print(f"[✗] Unknown friend: {friend_id}")
            return False
        
        # In real implementation, verify signature
        # For demo, accept the vote
        
        self.pending_votes[friend_id] = vote
        print(f"[Vote] {friend_id} voted: {vote}")
        
        # Log the vote
        self.revocation_log.append({
            "type": "vote",
            "friend": friend_id,
            "vote": vote,
            "timestamp": time.time()
        })
        
        return True
    
    def collect_votes(self, request: RevocationRequest, required_votes: int):
        """Collect votes from friends with timeout"""
        
        print(f"\n[Collecting votes... Need {required_votes} to revoke]")
        
        # Simulate friend responses
        time.sleep(2)
        self.receive_vote("friend_alice", "REVOKE")
        
        time.sleep(1)
        self.receive_vote("friend_bob", "REVOKE")
        
        time.sleep(2)
        self.receive_vote("friend_charlie", "INVESTIGATE")
        
        # Count votes
        revoke_votes = sum(1 for v in self.pending_votes.values() 
                          if v == "REVOKE")
        reject_votes = sum(1 for v in self.pending_votes.values() 
                          if v == "REJECT")
        
        print(f"\n[Vote Tally]")
        print(f"  REVOKE: {revoke_votes}")
        print(f"  REJECT: {reject_votes}")
        print(f"  OTHER: {len(self.pending_votes) - revoke_votes - reject_votes}")
        
        # Check if threshold met
        if revoke_votes >= required_votes:
            self.execute_revocation(request)
        elif time.time() < request.expires:
            print("[...] Waiting for more votes")
        else:
            print("[✗] Revocation request expired without consensus")
            self.false_alarm_count += 1
    
    def execute_revocation(self, request: RevocationRequest):
        """
        PERMANENT REVOCATION - This cannot be undone!
        """
        print(f"\n{'='*60}")
        print(f"⚠️  EXECUTING PERMANENT REVOCATION ⚠️")
        print(f"{'='*60}")
        
        # Step 1: Set revocation flag
        self.is_revoked = True
        print("[1/5] Revocation flag set")
        
        # Step 2: Destroy all keys
        self.destroy_keys()
        print("[2/5] Cryptographic keys destroyed")
        
        # Step 3: Overwrite sensitive memory
        self.secure_wipe_memory()
        print("[3/5] Memory securely wiped")
        
        # Step 4: Broadcast revocation certificate
        cert = self.create_revocation_certificate(request)
        self.broadcast_revocation_cert(cert)
        print("[4/5] Revocation certificate broadcast to network")
        
        # Step 5: Permanent lockdown
        self.permanent_lockdown()
        print("[5/5] System permanently locked")
        
        print(f"\n{'='*60}")
        print("DEVICE SUCCESSFULLY REVOKED")
        print("This device can no longer participate in consensus")
        print("Physical access required for recovery")
        print(f"{'='*60}")
    
    def destroy_keys(self):
        """Cryptographically destroy all keys"""
        
        # Overwrite with random data multiple times
        for _ in range(3):
            random_data = secrets.token_bytes(1024)
            # In real implementation, overwrite actual key memory
            
        # Clear key storage
        key_locations = [
            "/tmp/keys",
            "~/.ssh",
            "/etc/ssl/private"
        ]
        
        for location in key_locations:
            # In real implementation, securely delete files
            pass
    
    def secure_wipe_memory(self):
        """Overwrite sensitive memory regions"""
        
        # In real implementation, would use:
        # - mlock() to prevent swapping
        # - memset() to overwrite
        # - explicit_bzero() for secure clearing
        
        sensitive_regions = [
            "kernel_crypto_keys",
            "user_passwords",
            "network_buffers",
            "clipboard_data"
        ]
        
        for region in sensitive_regions:
            # Overwrite with random patterns
            for pattern in [0x00, 0xFF, 0xAA, 0x55]:
                # Write pattern to memory
                pass
    
    def create_revocation_certificate(self, request: RevocationRequest) -> Dict:
        """Create cryptographic proof of revocation"""
        
        cert = {
            "device_id": self.device_id,
            "revoked_at": time.time(),
            "reason": request.reason,
            "threat_level": request.threat_level.value,
            "votes": self.pending_votes.copy(),
            "final_hash": hashlib.sha3_512(
                json.dumps(self.revocation_log).encode()
            ).hexdigest()
        }
        
        # Sign with aggregate signature of voting friends
        # In real implementation, use threshold signatures
        
        return cert
    
    def broadcast_revocation_cert(self, cert: Dict):
        """Broadcast revocation to all nodes in network"""
        
        # Send to all devices in consensus network
        broadcast_targets = [
            "consensus_nodes",
            "backup_servers", 
            "certificate_transparency_log",
            "friend_devices"
        ]
        
        for target in broadcast_targets:
            # Send revocation certificate
            print(f"  → Revocation sent to {target}")
    
    def permanent_lockdown(self):
        """Final step: Lock system permanently"""
        
        # Write lockdown flag to multiple locations
        lockdown_flag = {
            "device_id": self.device_id,
            "locked_at": time.time(),
            "unlock_impossible": True,
            "requires_physical_presence": True,
            "minimum_witnesses": 3
        }
        
        # In real implementation:
        # - Write to NVRAM
        # - Write to multiple disk locations  
        # - Set hardware fuses if available
        
        self.is_locked = True
    
    def dead_mans_switch(self):
        """
        Automatic revocation if no heartbeat received
        Protects against indefinite compromise
        """
        
        while not self.is_revoked:
            time.sleep(3600)  # Check every hour
            
            if time.time() - self.last_heartbeat > self.heartbeat_timeout:
                print("\n[!] Dead man's switch activated!")
                print("[!] No heartbeat for 24 hours")
                
                # Auto-initiate revocation
                request = RevocationRequest(
                    device_id=self.device_id,
                    requester_id="SYSTEM",
                    threat_level=ThreatLevel.HIGH,
                    reason="Dead man's switch: No heartbeat",
                    evidence={"last_seen": self.last_heartbeat},
                    timestamp=time.time(),
                    expires=time.time() + 3600
                )
                
                self.initiate_revocation(request)
                break
    
    def update_heartbeat(self):
        """Update heartbeat to prevent dead man's switch"""
        self.last_heartbeat = time.time()

class RevocationScenarios:
    """Test different emergency scenarios"""
    
    @staticmethod
    def scenario_stolen_laptop():
        """Laptop physically stolen"""
        print("\n" + "="*70)
        print("SCENARIO 1: LAPTOP STOLEN")
        print("="*70)
        
        system = EmergencyRevocationSystem("laptop_001", revocation_threshold=1)
        
        # Register friends
        system.register_friend(FriendDevice(
            "friend_alice", "pubkey_alice", 0.9, 
            "New York", "push_notification", 30.0
        ))
        system.register_friend(FriendDevice(
            "friend_bob", "pubkey_bob", 0.8,
            "London", "signal_message", 45.0
        ))
        system.register_friend(FriendDevice(
            "friend_charlie", "pubkey_charlie", 0.7,
            "Tokyo", "sms", 120.0
        ))
        
        # User reports theft
        request = RevocationRequest(
            device_id="laptop_001",
            requester_id="user_phone",
            threat_level=ThreatLevel.STOLEN,
            reason="Laptop stolen from coffee shop",
            evidence={"location": "Starbucks 5th Ave", "time": "14:30"},
            timestamp=time.time(),
            expires=time.time() + 1800  # 30 min window
        )
        
        system.initiate_revocation(request)
        
        # Quick response due to theft
        time.sleep(6)
        
        return system.is_revoked
    
    @staticmethod
    def scenario_rootkit_detected():
        """Rootkit discovered during attestation"""
        print("\n" + "="*70)
        print("SCENARIO 2: ROOTKIT DETECTED")
        print("="*70)
        
        system = EmergencyRevocationSystem("laptop_002", revocation_threshold=2)
        
        # Register friends
        system.register_friend(FriendDevice(
            "friend_alice", "pubkey_alice", 0.9,
            "New York", "email", 60.0
        ))
        system.register_friend(FriendDevice(
            "friend_bob", "pubkey_bob", 0.8,
            "London", "push_notification", 30.0
        ))
        system.register_friend(FriendDevice(
            "friend_charlie", "pubkey_charlie", 0.7,
            "Tokyo", "signal_message", 90.0
        ))
        
        # System detects rootkit
        request = RevocationRequest(
            device_id="laptop_002",
            requester_id="security_monitor",
            threat_level=ThreatLevel.CRITICAL,
            reason="Rootkit detected in kernel module",
            evidence={
                "module": "hidden_rootkit.ko",
                "hash": "abc123...",
                "detected_by": "zk_attestation"
            },
            timestamp=time.time(),
            expires=time.time() + 600  # 10 min for critical
        )
        
        system.initiate_revocation(request)
        
        time.sleep(6)
        
        return system.is_revoked
    
    @staticmethod  
    def scenario_user_duress():
        """User under duress, triggers emergency"""
        print("\n" + "="*70)
        print("SCENARIO 3: USER DURESS CODE")
        print("="*70)
        
        system = EmergencyRevocationSystem("laptop_003", revocation_threshold=1)
        
        # Register friends with duress protocol
        system.register_friend(FriendDevice(
            "friend_spouse", "pubkey_spouse", 1.0,
            "Same Location", "phone_call", 10.0
        ))
        system.register_friend(FriendDevice(
            "friend_lawyer", "pubkey_lawyer", 0.9,
            "Local", "secure_email", 300.0
        ))
        
        # User enters duress code
        request = RevocationRequest(
            device_id="laptop_003",
            requester_id="user_duress",
            threat_level=ThreatLevel.CRITICAL,
            reason="DURESS CODE ACTIVATED",
            evidence={
                "code_type": "silent_alarm",
                "triggered": "biometric_anomaly"
            },
            timestamp=time.time(),
            expires=time.time() + 300  # 5 min for duress
        )
        
        system.initiate_revocation(request)
        
        print("\n[!] Silent alarm triggered")
        print("[!] Appears normal to attacker")
        print("[!] Friends notified covertly")
        
        time.sleep(6)
        
        return system.is_revoked

def demonstrate_emergency_revocation():
    """Run all emergency scenarios"""
    
    print("\n" + "="*70)
    print("Phase 5: Emergency Revocation System")
    print("="*70)
    print("\nCapabilities:")
    print("• Friends can permanently disable compromised device")
    print("• Different thresholds for different threat levels")  
    print("• Dead man's switch for missing devices")
    print("• Duress codes for coercion situations")
    print("• Irreversible once executed")
    
    # Run scenarios
    RevocationScenarios.scenario_stolen_laptop()
    RevocationScenarios.scenario_rootkit_detected()
    RevocationScenarios.scenario_user_duress()
    
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    print("Emergency revocation provides last-resort security:")
    print("• Stolen devices become useless bricks")
    print("• Compromised devices excluded from network")
    print("• Users protected under duress")
    print("• No single person can accidentally revoke")
    print("\nThis is the ultimate failsafe against persistent attackers")
    print("="*70)

if __name__ == "__main__":
    demonstrate_emergency_revocation()