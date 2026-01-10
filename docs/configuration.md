---
layout: default
title: Configuration
nav_order: 5
description: "Configuration options for Dokploy Enhanced"
permalink: /configuration/
---

# Configuration
{: .no_toc }

Customize your Dokploy Enhanced deployment.
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

## Configuration Files

All configuration is stored in `/etc/dokploy/`:

```
/etc/dokploy/
├── .env                    # Main configuration file
├── docker-compose.yml      # Stack definition
└── traefik/
    ├── traefik.yml         # Traefik static config
    └── dynamic/            # Traefik dynamic configs
```

---

## Environment Variables

Edit `/etc/dokploy/.env` to configure your deployment.

### Core Settings

```bash
# Docker image settings
DOKPLOY_REGISTRY=ghcr.io/amirhmoradi
DOKPLOY_IMAGE=dokploy-enhanced
DOKPLOY_VERSION=latest

# Network settings
ADVERTISE_ADDR=192.168.1.100
DOKPLOY_PORT=3000
NETWORK_NAME=dokploy-network
```

### Database Settings

```bash
# PostgreSQL configuration
POSTGRES_VERSION=16
POSTGRES_USER=dokploy
POSTGRES_DB=dokploy
POSTGRES_PASSWORD=your-secure-password
```

{: .warning }
> Never commit `.env` files with real passwords to version control.

### Cache Settings

```bash
# Redis/Valkey configuration
REDIS_VERSION=8
```

### Traefik Settings

```bash
# Reverse proxy configuration
TRAEFIK_VERSION=v3.1.6
TRAEFIK_ENABLED=true

# SSL/Let's Encrypt
ACME_EMAIL=admin@example.com
```

---

## Full Variable Reference

| Variable | Default | Description |
|:---------|:--------|:------------|
| `DOKPLOY_REGISTRY` | `ghcr.io/amirhmoradi` | Container registry |
| `DOKPLOY_IMAGE` | `dokploy-enhanced` | Image name |
| `DOKPLOY_VERSION` | `latest` | Image tag |
| `DOKPLOY_PORT` | `3000` | Web UI port |
| `ADVERTISE_ADDR` | Auto-detected | Docker Swarm address |
| `DATA_DIR` | `/etc/dokploy` | Data directory |
| `NETWORK_NAME` | `dokploy-network` | Docker network |
| `POSTGRES_VERSION` | `16` | PostgreSQL version |
| `POSTGRES_USER` | `dokploy` | Database user |
| `POSTGRES_DB` | `dokploy` | Database name |
| `POSTGRES_PASSWORD` | Auto-generated | Database password |
| `REDIS_VERSION` | `8` | Valkey/Redis version |
| `TRAEFIK_VERSION` | `v3.1.6` | Traefik version |
| `TRAEFIK_ENABLED` | `true` | Enable Traefik |
| `ACME_EMAIL` | - | Let's Encrypt email |

---

## Applying Changes

After editing `.env`:

```bash
cd /etc/dokploy
./install.sh restart
```

Or using docker-compose directly:

```bash
cd /etc/dokploy
docker compose up -d
```

---

## Management Commands

### Service Control

```bash
# Start all services
./install.sh start

# Stop all services
./install.sh stop

# Restart all services
./install.sh restart

# Check status
./install.sh status
```

### Logs

```bash
# All services
./install.sh logs

# Follow mode
./install.sh logs -f

# Specific service
./install.sh logs dokploy
./install.sh logs postgres -f
```

### Updates

```bash
# Pull latest and restart
./install.sh update
```

### Backups

```bash
# Create backup
./install.sh backup

# Backups stored in /var/backups/dokploy/
```

---

## Docker Compose Commands

You can also use standard docker-compose commands:

```bash
cd /etc/dokploy

# View running containers
docker compose ps

# Pull latest images
docker compose pull

# Recreate containers
docker compose up -d

# View logs
docker compose logs -f dokploy

# Stop everything
docker compose down
```

---

## Advanced Configuration

### Custom Docker Network

```bash
# In .env
NETWORK_NAME=my-custom-network
```

### External Database

To use an external PostgreSQL database, modify `docker-compose.yml`:

```yaml
services:
  dokploy:
    environment:
      - DATABASE_URL=postgresql://user:pass@host:5432/dokploy
    # Remove depends_on: postgres
```

### Custom Traefik Configuration

Edit `/etc/dokploy/traefik/traefik.yml` for static configuration or add files to `/etc/dokploy/traefik/dynamic/` for dynamic configuration.

### SSL Certificates

With Traefik enabled, SSL is automatic via Let's Encrypt:

```bash
# In .env
ACME_EMAIL=admin@yourdomain.com
```

Certificates are stored in `/etc/dokploy/traefik/acme/`.

---

## Automated Backups

Add to crontab for daily backups:

```bash
crontab -e
```

Add:
```
0 2 * * * /etc/dokploy/install.sh backup 2>&1 | logger -t dokploy-backup
```

This runs backups at 2 AM daily.

---

## Next Steps

- [Migration from official Dokploy]({% link migration.md %})
- [Troubleshooting]({% link troubleshooting.md %})
