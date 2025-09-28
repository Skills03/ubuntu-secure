#!/bin/bash
# AWS EC2 Free Tier deployment

# Launch EC2 instance
aws ec2 run-instances \
    --image-id ami-0c02fb55731490381 \
    --instance-type t2.micro \
    --key-name MyKeyPair \
    --security-group-ids sg-903004f8 \
    --user-data file://cloud-init.yaml \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ubuntu-blockchain}]'

# Get instance IP
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=ubuntu-blockchain" --query 'Reservations[0].Instances[0].InstanceId' --output text)
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Deployed to: http://$PUBLIC_IP:8080"
