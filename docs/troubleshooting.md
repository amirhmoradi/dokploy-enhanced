---
layout: default
title: Troubleshooting
nav_order: 8
description: "Common issues and solutions for Dokploy Enhanced"
permalink: /troubleshooting/
---

# Troubleshooting
{: .no_toc }

Solutions to common problems.
{: .fs-6 .fw-300 }

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

---

## Quick Diagnostics

### Check Service Status

```bash
./install.sh status
# or
cd /etc/dokploy && docker compose ps
```

### View Logs

```bash
# All services
./install.sh logs

# Follow mode
./install.sh logs -f

# Specific service
./install.sh logs dokploy -f
./install.sh logs postgres -f
```

### Check Docker

```bash
# Docker daemon
systemctl status docker

# Docker Swarm
docker info | grep Swarm

# Networks
docker network ls
```

---

## Installation Issues

### Docker Not Installing

**Symptoms**: Install script fails during Docker installation.

**Solution**:

```bash
# Install Docker manually
curl -fsSL https://get.docker.com | sh

# Then run install with skip
SKIP_DOCKER_INSTALL=true ./install.sh
```

### Port Already in Use

**Symptoms**: Error about port 3000 (or other port) being in use.

**Solution**:

```bash
# Find what's using the port
ss -tulnp | grep :3000

# Option 1: Stop the conflicting service
systemctl stop <service-name>

# Option 2: Use a different port
DOKPLOY_PORT=8080 ./install.sh
```

### Permission Denied

**Symptoms**: Permission errors during installation.

**Solution**:

```bash
# Run as root
sudo ./install.sh

# Or with sudo
curl -sSL ... | sudo bash
```

### Docker Swarm Issues

**Symptoms**: Swarm initialization fails.

**Solution**:

```bash
# Leave any existing swarm
docker swarm leave --force

# Reinitialize with specific address
docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
```

---

## Service Issues

### Dokploy Won't Start

**Symptoms**: Dokploy container exits or restarts repeatedly.

**Diagnosis**:

```bash
docker compose -f /etc/dokploy/docker-compose.yml logs dokploy
```

**Common causes**:

1. **Database not ready**: Wait for PostgreSQL health check
2. **Wrong environment variables**: Check `.env` file
3. **Network issues**: Verify Docker networks exist

**Solution**:

```bash
# Restart all services
./install.sh restart

# Or recreate
cd /etc/dokploy
docker compose down
docker compose up -d
```

### Database Connection Failed

**Symptoms**: "Connection refused" or "Authentication failed" errors.

**Diagnosis**:

```bash
# Check PostgreSQL status
docker compose -f /etc/dokploy/docker-compose.yml logs postgres

# Test connection
docker exec dokploy-postgres pg_isready -U dokploy -d dokploy
```

**Solution**:

```bash
# Verify password matches
cat /etc/dokploy/.env | grep POSTGRES_PASSWORD

# Restart PostgreSQL
docker compose -f /etc/dokploy/docker-compose.yml restart postgres
```

### Redis Connection Failed

**Symptoms**: Session or cache errors.

**Diagnosis**:

```bash
docker compose -f /etc/dokploy/docker-compose.yml logs redis

# Test connection
docker exec dokploy-redis redis-cli ping
```

**Solution**:

```bash
docker compose -f /etc/dokploy/docker-compose.yml restart redis
```

### Traefik Not Working

**Symptoms**: Can't access via domain, SSL errors.

**Diagnosis**:

```bash
docker compose -f /etc/dokploy/docker-compose.yml logs traefik
```

**Solution**:

```bash
# Check Traefik dashboard (if enabled)
curl http://localhost:8080/dashboard/

# Verify certificates
ls -la /etc/dokploy/traefik/acme/

# Restart Traefik
docker compose -f /etc/dokploy/docker-compose.yml restart traefik
```

---

## Build Issues

### Workflow Fails with Merge Conflict

**Symptoms**: GitHub Action fails at merge step.

**Diagnosis**: Check workflow logs for conflict details.

**Solution**:

1. Remove the conflicting PR from `PR_NUMBERS_TO_MERGE`
2. Or wait for upstream to update (conflicts may resolve)
3. Manually trigger a new build

### Image Not Found

**Symptoms**: `docker pull` fails with "not found".

**Possible causes**:

1. Build hasn't completed yet
2. Registry is private
3. Wrong image name

**Solution**:

```bash
# Check your packages
# Go to: github.com/YOUR_USERNAME?tab=packages

# Make package public if needed
# Package settings -> Change visibility -> Public

# Verify image name
docker pull ghcr.io/YOUR_USERNAME/dokploy-enhanced:latest
```

### Build Takes Too Long

**Symptoms**: Builds timeout or take 30+ minutes.

**Solution**: This is normal for first builds. Subsequent builds use cache and are faster.

---

## Network Issues

### Can't Access Web UI

**Symptoms**: Browser can't connect to Dokploy.

**Diagnosis**:

```bash
# Check if service is listening
ss -tulnp | grep :3000

# Check firewall
sudo ufw status
# or
sudo firewall-cmd --list-all
```

**Solution**:

```bash
# Open port in firewall
sudo ufw allow 3000/tcp
# or
sudo firewall-cmd --add-port=3000/tcp --permanent
sudo firewall-cmd --reload
```

### SSL Certificate Issues

**Symptoms**: Browser shows certificate warnings.

**Diagnosis**:

```bash
# Check Traefik logs for ACME errors
docker compose -f /etc/dokploy/docker-compose.yml logs traefik | grep -i acme
```

**Common causes**:

1. DNS not pointing to server
2. Port 80/443 blocked
3. Rate limited by Let's Encrypt

**Solution**:

```bash
# Verify DNS
dig +short yourdomain.com

# Check ports are open
curl -I http://yourdomain.com

# Clear ACME state (forces new cert)
rm -rf /etc/dokploy/traefik/acme/*
docker compose -f /etc/dokploy/docker-compose.yml restart traefik
```

---

## Environment-Specific Issues

### Proxmox LXC Containers

**Requirements**:

- Enable nesting in container options
- Enable keyctl feature
- Use unprivileged container with proper configuration

**Container config** (`/etc/pve/lxc/XXX.conf`):

```text
features: keyctl=1,nesting=1
```

### WSL (Windows Subsystem for Linux)

{: .warning }
> WSL has significant limitations with Docker networking. For production, use a proper Linux server.

**Known issues**:

- Port forwarding may not work
- Docker Swarm networking is unreliable
- Performance is reduced

**Recommendation**: Use WSL only for testing. Deploy to Linux server/VM for production.

### Low Memory Systems

**Symptoms**: Services crash or are killed (OOM).

**Solution**:

```bash
# Add swap if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## Recovery Procedures

### Reset Everything

{: .warning }
> This deletes all data. Create a backup first!

```bash
# Backup first
./install.sh backup

# Complete reset
./install.sh uninstall

# Fresh install
./install.sh install
```

### Restore from Backup

```bash
# List backups
ls /var/backups/dokploy/

# Restore PostgreSQL
docker run --rm \
  -v dokploy-postgres:/data \
  -v /var/backups/dokploy/BACKUP_DATE:/backup \
  alpine tar xzf /backup/postgres.tar.gz -C /data

# Restart services
./install.sh restart
```

### Force Recreate Services

```bash
cd /etc/dokploy
docker compose down
docker compose up -d --force-recreate
```

---

## Getting Help

If you can't resolve the issue:

1. **Check existing issues**: [GitHub Issues](https://github.com/amirhmoradi/dokploy-enhanced/issues)

2. **Open a new issue** with:
   - Operating system and version
   - Docker version (`docker --version`)
   - Error messages
   - Relevant logs (`./install.sh logs`)
   - Steps to reproduce

3. **Community support**: Check Dokploy's community channels for general Dokploy issues
