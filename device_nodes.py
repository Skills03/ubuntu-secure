#!/usr/bin/env python3
"""
Phase 2: Device nodes for distributed boot verification
These simulate the different devices that hold key shares
"""

import socket
import json
import threading
import time
from typing import Dict, Tuple

class DeviceNode:
    """
    Simulates a device (phone/yubikey/friend/cloud/pi) that holds a key share
    In real implementation, these would run on actual separate devices
    """
    
    def __init__(self, device_type: str, port: int, share: Tuple[int, int]):
        self.device_type = device_type
        self.port = port
        self.share = share
        self.approved_requests = set()
        self.server_thread = None
        self.running = False
        
    def handle_client(self, client_socket: socket.socket, address):
        """Handle incoming boot requests"""
        try:
            # Receive request
            data = client_socket.recv(1024).decode()
            request = json.loads(data)
            
            print(f"[{self.device_type}] Received boot request from {address[0]}")
            
            # Simulate different device behaviors
            if self.device_type == "phone":
                # Phone auto-approves if unlocked (simulated)
                print(f"[{self.device_type}] Auto-approving (phone unlocked)")
                response = {
                    "approved": True,
                    "share": self.share,
                    "device": self.device_type,
                    "timestamp": time.time()
                }
                
            elif self.device_type == "yubikey":
                # YubiKey requires physical touch (simulated delay)
                print(f"[{self.device_type}] Waiting for physical touch...")
                time.sleep(1)  # Simulate user touching key
                response = {
                    "approved": True,
                    "share": self.share,
                    "device": self.device_type,
                    "timestamp": time.time()
                }
                
            elif self.device_type == "friend":
                # Friend device requires manual approval (simulated)
                print(f"[{self.device_type}] Sending notification to friend...")
                print(f"[{self.device_type}] Friend approved the request!")
                response = {
                    "approved": True,
                    "share": self.share,
                    "device": self.device_type,
                    "timestamp": time.time()
                }
                
            elif self.device_type == "cloud":
                # Cloud HSM verifies request signature (simulated)
                print(f"[{self.device_type}] Verifying request signature...")
                response = {
                    "approved": True,
                    "share": self.share,
                    "device": self.device_type,
                    "timestamp": time.time()
                }
                
            elif self.device_type == "pi":
                # Raspberry Pi checks if on home network (simulated)
                print(f"[{self.device_type}] Checking network location...")
                response = {
                    "approved": True,
                    "share": self.share,
                    "device": self.device_type,
                    "timestamp": time.time()
                }
            else:
                response = {"approved": False, "reason": "Unknown device type"}
            
            # Send response
            client_socket.send(json.dumps(response).encode())
            
        except Exception as e:
            print(f"[{self.device_type}] Error handling request: {e}")
            error_response = {"approved": False, "reason": str(e)}
            client_socket.send(json.dumps(error_response).encode())
        finally:
            client_socket.close()
    
    def start(self):
        """Start the device node server"""
        self.running = True
        server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        
        try:
            server_socket.bind(('localhost', self.port))
            server_socket.listen(5)
            print(f"[{self.device_type}] Listening on port {self.port}")
            
            while self.running:
                server_socket.settimeout(1.0)
                try:
                    client_socket, address = server_socket.accept()
                    # Handle each client in a new thread
                    client_thread = threading.Thread(
                        target=self.handle_client,
                        args=(client_socket, address)
                    )
                    client_thread.start()
                except socket.timeout:
                    continue
                except Exception as e:
                    if self.running:
                        print(f"[{self.device_type}] Server error: {e}")
                        
        finally:
            server_socket.close()
    
    def stop(self):
        """Stop the device node server"""
        self.running = False

class DeviceNetwork:
    """
    Manages the network of devices holding key shares
    This simulates having multiple physical devices
    """
    
    def __init__(self, shares: list):
        # Create device nodes with their shares
        self.devices = {
            "phone": DeviceNode("phone", 8001, shares[0]),
            "yubikey": DeviceNode("yubikey", 8002, shares[1]),
            "friend": DeviceNode("friend", 8003, shares[2]),
            "cloud": DeviceNode("cloud", 8004, shares[3]),
            "pi": DeviceNode("pi", 8005, shares[4])
        }
        self.threads = {}
    
    def start_all(self):
        """Start all device nodes in separate threads"""
        print("\n=== Starting Device Network ===")
        for name, device in self.devices.items():
            thread = threading.Thread(target=device.start)
            thread.daemon = True
            thread.start()
            self.threads[name] = thread
        print(f"Started {len(self.devices)} device nodes\n")
        time.sleep(1)  # Give servers time to start
    
    def stop_all(self):
        """Stop all device nodes"""
        print("\n=== Stopping Device Network ===")
        for device in self.devices.values():
            device.stop()
        for thread in self.threads.values():
            thread.join(timeout=2)
        print("All device nodes stopped\n")

def test_device_network():
    """Test the device network setup"""
    # Mock shares for testing
    test_shares = [(1, 111), (2, 222), (3, 333), (4, 444), (5, 555)]
    
    # Create and start network
    network = DeviceNetwork(test_shares)
    network.start_all()
    
    # Test connecting to each device
    print("=== Testing Device Connections ===")
    for device_name, device in network.devices.items():
        try:
            # Connect to device
            client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            client.settimeout(5)
            client.connect(('localhost', device.port))
            
            # Send request
            request = {"action": "request_share", "purpose": "boot"}
            client.send(json.dumps(request).encode())
            
            # Get response
            response = json.loads(client.recv(1024).decode())
            client.close()
            
            if response.get("approved"):
                print(f"✓ {device_name}: Share received")
            else:
                print(f"✗ {device_name}: {response.get('reason')}")
                
        except Exception as e:
            print(f"✗ {device_name}: Connection failed - {e}")
    
    # Stop network
    network.stop_all()

if __name__ == "__main__":
    test_device_network()