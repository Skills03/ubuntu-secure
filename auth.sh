#!/bin/bash
# Authentication wrapper for ttyd
exec ttyd --writable \
  --credential ubuntu:secure2025 \
  --ssl \
  --ssl-cert=/workspace/ssl/cert.pem \
  --ssl-key=/workspace/ssl/key.pem \
  -p 7681 \
  bash