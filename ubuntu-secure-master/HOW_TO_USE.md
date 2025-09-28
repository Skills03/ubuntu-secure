# Ubuntu Secure on Blockchain - User Guide

## Quick Start (For Users)

### 1. Access the System

Visit: http://167.71.230.138

Or use these endpoints:
- Web Interface: http://167.71.230.138
- Blockchain Explorer: http://167.71.230.138:9944
- Boot Server: http://167.71.230.138:8888
- IPFS Gateway: http://167.71.230.138:8080

### 2. Connect Your Devices

#### On Your Phone:
1. Install the Ubuntu Secure app (or use web)
2. Visit: http://167.71.230.138/connect
3. Scan this QR code:

   Device ID: 9f707444b7b3b5ead8fb8048aa4e6d24
   Access Token: acce751a9e11bbaf2791e1dea41c7286a359d2b1f7dc7a1614836a7852ddbf90

#### On Your Computer:
```bash
# Method 1: Network Boot (Stateless)
# Reboot and select network boot (PXE)
# Your BIOS will boot from: http://167.71.230.138:8888

# Method 2: Script Install
curl -fsSL http://167.71.230.138/install.sh | bash

# Method 3: Docker
docker run -it --rm \
  -e BLOCKCHAIN=ws://167.71.230.138:9944 \
  -e DEVICE_ID=9f707444b7b3b5ead8fb8048aa4e6d24 \
  ubuntu-secure/client
```

### 3. Register Friends for Recovery

```bash
# Share this with trusted friends:
curl http://167.71.230.138/add-friend \
  -H "Authorization: acce751a9e11bbaf2791e1dea41c7286a359d2b1f7dc7a1614836a7852ddbf90" \
  -d "friend_device=FRIEND_DEVICE_ID"
```

### 4. Daily Usage

Every critical operation will:
1. Request consensus from your devices
2. Show notification on your phone
3. Require 2+ device approval
4. Execute only if approved

Example:
- You: `sudo apt install something`
- Phone: "Approve sudo command?" [Yes/No]
- Cloud: Auto-approves if safe
- Result: Command executes or blocks

### 5. Boot Your Computer (Stateless)

1. Configure BIOS:
   - Enable Network Boot (PXE)
   - Set boot order: Network first

2. On boot:
   - Computer requests boot from blockchain
   - Your phone gets notification
   - Approve boot on 2+ devices
   - Ubuntu loads entirely from network
   - Nothing stored on local disk

## Security Features Active

✓ **Phase 1-3**: Multi-device consensus
✓ **Phase 4**: Zero-knowledge attestation
✓ **Phase 5**: Friend emergency revocation
✓ **Phase 6**: Homomorphic encryption
✓ **Phase 7**: Quantum-resistant crypto
✓ **Phase 8**: Stateless network boot

## Test Your Security

```bash
# Test if system is working
curl http://167.71.230.138/api/status

# Simulate attack
curl http://167.71.230.138/api/simulate-attack

# Check your device status
curl http://167.71.230.138/api/device/9f707444b7b3b5ead8fb8048aa4e6d24
```

## Emergency Procedures

### If Your Laptop is Stolen:
```bash
# From any device:
curl http://167.71.230.138/api/revoke \
  -H "Authorization: acce751a9e11bbaf2791e1dea41c7286a359d2b1f7dc7a1614836a7852ddbf90" \
  -d "device=9f707444b7b3b5ead8fb8048aa4e6d24&reason=stolen"
```

### If You Suspect Compromise:
1. Friends automatically get alert
2. 2 friends must approve revocation
3. Device permanently disabled

## Blockchain Details

- Blockchain Type: Substrate/Polkadot
- Consensus: GRANDPA + AURA
- Block Time: ~6 seconds
- Validators: 3 (x86, ARM, RISC-V)
- Explorer: http://167.71.230.138:9944

## Your Unique Credentials

```
Device ID: 9f707444b7b3b5ead8fb8048aa4e6d24
Access Token: acce751a9e11bbaf2791e1dea41c7286a359d2b1f7dc7a1614836a7852ddbf90
Blockchain: ws://167.71.230.138:9944
Boot Server: http://167.71.230.138:8888
```

## Support

- GitHub: https://github.com/ubuntu-secure/core
- Issues: https://github.com/ubuntu-secure/core/issues

---
**Your laptop is compromised? So what. It's just 1 vote out of N.**
