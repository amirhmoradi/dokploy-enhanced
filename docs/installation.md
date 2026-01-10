---
layout: default
title: Installation
nav_order: 4
description: "Complete installation guide for Dokploy Enhanced"
permalink: /installation/
---

# Installation Guide
{: .no_toc }

Deploy Dokploy Enhanced to your server.
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

## Requirements

### System Requirements

| Resource | Minimum | Recommended |
|:---------|:--------|:------------|
| **RAM** | 2 GB | 4 GB+ |
| **Disk Space** | 30 GB | 50 GB+ |
| **CPU** | 1 core | 2+ cores |
| **OS** | Linux (Ubuntu, Debian, CentOS, RHEL, Fedora) | Ubuntu 22.04 LTS |
| **Architecture** | x86_64 (amd64), arm64 | x86_64 |

### Network Requirements

| Port | Service | Required |
|:-----|:--------|:---------|
| 80 | HTTP (Traefik) | For HTTPS redirect |
| 443 | HTTPS (Traefik) | For SSL termination |
| 3000 | Dokploy Web UI | Yes |
| 2377 | Docker Swarm | For clustering |

{: .note }
> Ports 80 and 443 are only required if using Traefik. You can use `SKIP_TRAEFIK=true` if you have your own reverse proxy.

---

## Quick Install

One command to deploy everything:

```bash
curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

The installer will:

1. Check system requirements
2. Install Docker and Docker Compose (if needed)
3. Initialize Docker Swarm
4. Create required networks
5. Generate configuration files
6. Deploy the full stack
7. Display access information

---

## Custom Installation

### Using Your Own Fork

```bash
DOKPLOY_REGISTRY=ghcr.io/YOUR_USERNAME \
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/dokploy-enhanced/main/install.sh | bash
```

### Custom Port

```bash
DOKPLOY_PORT=8080 \
curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

### Without Traefik

If you have your own reverse proxy (nginx, Caddy, etc.):

```bash
SKIP_TRAEFIK=true \
curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

### Specific Version

```bash
DOKPLOY_VERSION=20250110 \
curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

### Force Mode

Skip all confirmations (for automation):

```bash
FORCE=true \
curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

### Combined Options

```bash
DOKPLOY_PORT=8080 \
SKIP_TRAEFIK=true \
DOKPLOY_REGISTRY=ghcr.io/mycompany \
curl -sSL https://raw.githubusercontent.com/mycompany/dokploy-enhanced/main/install.sh | bash
```

---

## Environment Variables

| Variable | Default | Description |
|:---------|:--------|:------------|
| `DOKPLOY_VERSION` | `latest` | Docker image tag |
| `DOKPLOY_PORT` | `3000` | Web interface port |
| `DOKPLOY_REGISTRY` | `ghcr.io/amirhmoradi` | Docker registry |
| `DOKPLOY_IMAGE` | `dokploy-enhanced` | Image name |
| `DOKPLOY_DATA_DIR` | `/etc/dokploy` | Data directory |
| `ADVERTISE_ADDR` | Auto-detected | Docker Swarm address |
| `SKIP_DOCKER_INSTALL` | `false` | Skip Docker installation |
| `SKIP_TRAEFIK` | `false` | Skip Traefik deployment |
| `POSTGRES_PASSWORD` | Auto-generated | Database password |
| `FORCE` | `false` | Skip confirmations |
| `DEBUG` | `false` | Enable debug output |
| `DRY_RUN` | `false` | Test without changes |

---

## What Gets Installed

### Services

| Service | Image | Purpose |
|:--------|:------|:--------|
| **Dokploy** | `ghcr.io/.../dokploy-enhanced` | Main application |
| **PostgreSQL 16** | `postgres:16` | Database |
| **Valkey** | `valkey/valkey:8` | Cache (Redis-compatible) |
| **Traefik** | `traefik:v3.1.6` | Reverse proxy (optional) |

### Files Created

```
/etc/dokploy/
├── .env                    # Configuration variables
├── docker-compose.yml      # Stack definition
├── install-info.json       # Installation metadata
└── traefik/                # Traefik configs (if enabled)
    ├── traefik.yml
    ├── dynamic/
    └── acme/               # SSL certificates
```

---

## Post-Installation

### Access Dokploy

After installation:

```
URL: http://YOUR_SERVER_IP:3000
```

Create your admin account on first access.

### Verify Installation

```bash
./install.sh status
```

Expected output:
```
NAME                STATUS    PORTS
dokploy             running   0.0.0.0:3000->3000/tcp
dokploy-postgres    running   5432/tcp
dokploy-redis       running   6379/tcp
dokploy-traefik     running   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
```

### View Logs

```bash
./install.sh logs -f
```

---

## Updating

Pull latest images and restart:

```bash
./install.sh update
```

Or manually:

```bash
cd /etc/dokploy
docker compose pull
docker compose up -d
```

---

## Uninstalling

{: .warning }
> This will remove all services and data. Create a backup first!

```bash
./install.sh backup
./install.sh uninstall
```

---

## Next Steps

- [Configure your installation]({% link configuration.md %})
- [Migrate from official Dokploy]({% link migration.md %})
- [Troubleshooting]({% link troubleshooting.md %})
