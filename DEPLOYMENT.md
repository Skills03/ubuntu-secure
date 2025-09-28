# Ubuntu Secure - Live Deployment

## Current Status: ✅ DEPLOYED & RUNNING

### Server Details
- **Platform:** DigitalOcean Droplet
- **OS:** Ubuntu 22.04
- **Resources:** 4GB RAM, 2 CPUs, 80GB disk
- **Cost:** $20/month

### Services Running
```bash
docker-compose ps
```

| Service | Port | Status | Purpose |
|---------|------|--------|---------|
| api | 8000 | ✅ Running | API endpoints for consensus |
| blockchain | - | ✅ Running | Continuous security demos |
| web | 8080 | ✅ Running | User interface |

### API Endpoints Live
- `GET /health` - System status
- `GET /consensus` - 5-device consensus status
- `GET /boot` - Secure boot demonstration
- `GET /state` - Blockchain state
- `GET /` - API documentation

### Quick Commands
```bash
# Check system status
curl http://localhost:8000/health

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Stop everything
docker-compose down

# Start everything
docker-compose up -d
```

### Architecture
```
User Browser → nginx:8080 → Web Interface
User API → api:8000 → Consensus Status
Background → blockchain → Security Demonstrations
```

### Security Demo
- **Laptop:** COMPROMISED (simulated)
- **Phone, Pi, Cloud, Friend:** TRUSTED
- **Consensus:** 3 of 5 required
- **Result:** Operations continue despite compromise

### Deployment Time
- **Total:** 30 minutes
- **Setup:** 25 minutes
- **Testing:** 5 minutes

### Next Steps
1. Point domain to server IP
2. Set up SSL with certbot
3. Share with users
4. Monitor with `docker-compose logs`

---
*"Your laptop is compromised? Doesn't matter. The OS lives on the blockchain."*