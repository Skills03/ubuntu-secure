#!/usr/bin/env python3
"""
Ubuntu Blockchain OS - Device Client
Run this on your phone/computer/pi to participate in consensus
"""

import requests
import json
import time
import hashlib
import sys
from typing import Dict

class DeviceClient:
    """Simple client that votes on operations"""
    
    def __init__(self, server_url: str, device_name: str):
        self.server = server_url
        self.device = device_name
        self.connected = False
        
    def connect(self) -> bool:
        """Connect to Ubuntu Blockchain OS"""
        try:
            r = requests.get(f"{self.server}/health")
            if r.json()["status"] == "running":
                self.connected = True
                print(f"✓ Connected to Ubuntu Blockchain OS as '{self.device}'")
                return True
        except:
            print(f"✗ Cannot connect to {self.server}")
            return False
    
    def vote(self, operation: str, vote: str) -> Dict:
        """Vote on an operation"""
        data = {
            "device": self.device,
            "vote": vote,
            "operation": operation
        }
        
        r = requests.post(f"{self.server}/vote", json=data)
        return r.json()
    
    def auto_approve_safe(self, operation: str) -> bool:
        """Auto-approve safe operations"""
        safe_operations = ["boot", "read", "list", "status"]
        dangerous_operations = ["delete", "format", "sudo", "rm"]
        
        # Auto-deny dangerous
        if any(danger in operation.lower() for danger in dangerous_operations):
            print(f"  ✗ Auto-DENY dangerous: {operation}")
            return False
        
        # Auto-approve safe
        if any(safe in operation.lower() for safe in safe_operations):
            print(f"  ✓ Auto-APPROVE safe: {operation}")
            return True
        
        # Ask user for others
        response = input(f"  ? Approve '{operation}'? (y/n): ")
        return response.lower() == 'y'
    
    def monitor(self):
        """Monitor and vote on operations"""
        print(f"\n📡 Monitoring as '{self.device}'...")
        print("Will auto-approve safe operations, ask for others\n")
        
        last_check = 0
        
        while True:
            try:
                # Check for pending operations
                r = requests.get(f"{self.server}/state")
                state = r.json()
                
                # Simple simulation - in real version, would get actual pending ops
                if time.time() - last_check > 10:
                    print(f"[{time.strftime('%H:%M:%S')}] Checking for operations...")
                    
                    # Simulate receiving operation request
                    if state["operations"] % 3 == 0:  # Every 3rd check
                        operation = "boot_ubuntu"
                        print(f"\n🔔 New operation request: {operation}")
                        
                        if self.auto_approve_safe(operation):
                            result = self.vote(operation, "approve")
                            print(f"  → Voted APPROVE")
                        else:
                            result = self.vote(operation, "deny")
                            print(f"  → Voted DENY")
                        
                        if "result" in result:
                            print(f"\n📊 Consensus reached: {result['result'].upper()}")
                    
                    last_check = time.time()
                
                time.sleep(5)
                
            except KeyboardInterrupt:
                print("\n\n👋 Disconnecting...")
                break
            except Exception as e:
                print(f"Connection error: {e}")
                time.sleep(10)

def main():
    print("====================================")
    print("Ubuntu Blockchain OS - Device Client")
    print("====================================\n")
    
    # Get server URL
    if len(sys.argv) > 1:
        server = sys.argv[1]
    else:
        server = input("Enter server URL (e.g., http://ubuntu-blockchain.org:8000): ")
        if not server:
            server = "http://localhost:8000"
    
    # Get device name
    if len(sys.argv) > 2:
        device = sys.argv[2]
    else:
        print("\nWhat device is this?")
        print("1. Phone")
        print("2. Laptop")
        print("3. Raspberry Pi")
        print("4. Friend's Computer")
        print("5. Custom")
        
        choice = input("\nSelect (1-5): ")
        
        devices = {
            "1": "phone",
            "2": "laptop",
            "3": "raspberry_pi",
            "4": "friend",
            "5": input("Enter device name: ")
        }
        device = devices.get(choice, "unknown")
    
    # Create client
    client = DeviceClient(server, device)
    
    # Connect
    if not client.connect():
        print("\n Failed to connect. Check server is running.")
        return
    
    # Start monitoring
    client.monitor()

if __name__ == "__main__":
    main()