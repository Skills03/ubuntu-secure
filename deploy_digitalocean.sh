#!/bin/bash
# DigitalOcean $5/month deployment

# Create droplet
doctl compute droplet create ubuntu-blockchain \
    --region nyc1 \
    --size s-1vcpu-1gb \
    --image ubuntu-22-04-x64 \
    --ssh-keys $(doctl compute ssh-key list --format ID --no-header) \
    --user-data-file cloud-init.yaml

# Get droplet IP
IP=$(doctl compute droplet get ubuntu-blockchain --format PublicIPv4 --no-header)

# SSH and deploy
ssh root@$IP << 'ENDSSH'
apt update && apt install -y python3-pip git
git clone https://github.com/ubuntu-secure/blockchain-os.git
cd blockchain-os
pip3 install -r requirements.txt
python3 ubuntu_blockchain_os.py &
ENDSSH

echo "Deployed to: http://$IP:8080"
