# Dokploy Enhanced

[![Auto Merge and Build](https://github.com/amirhmoradi/dokploy-enhanced/actions/workflows/auto-merge-build.yml/badge.svg)](https://github.com/amirhmoradi/dokploy-enhanced/actions/workflows/auto-merge-build.yml)
[![Docker Image](https://img.shields.io/badge/docker-ghcr.io%2Famirhmoradi%2Fdokploy--enhanced-blue)](https://ghcr.io/amirhmoradi/dokploy-enhanced)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Dokploy Enhanced** is an automated, enhanced distribution of [Dokploy](https://github.com/Dokploy/dokploy) - the open-source, self-hosted Platform as a Service (PaaS) alternative to Vercel, Netlify, and Heroku. This project automatically merges community pull requests, builds optimized Docker images, and provides an enterprise-grade installation experience with docker-compose.

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [How It Works](#how-it-works)
- [Quick Start](#quick-start)
- [Installation Guide](#installation-guide)
  - [Requirements](#requirements)
  - [Basic Installation](#basic-installation)
  - [Advanced Configuration](#advanced-configuration)
  - [Environment Variables](#environment-variables)
- [Configuration Files](#configuration-files)
- [Commands Reference](#commands-reference)
- [Migration from Official Dokploy](#migration-from-official-dokploy)
- [Docker Compose](#docker-compose)
- [GitHub Actions Workflow](#github-actions-workflow)
  - [Configuring PR Merges](#configuring-pr-merges)
  - [Manual Workflow Triggers](#manual-workflow-triggers)
  - [Build Configuration](#build-configuration)
- [Docker Images](#docker-images)
- [Backup and Restore](#backup-and-restore)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Overview

Dokploy Enhanced solves a common challenge in open-source projects: valuable community contributions often wait in pull request queues while users need those fixes and features immediately. This project automatically:

1. **Syncs Daily** with the upstream Dokploy repository
2. **Merges Selected PRs** from a configurable list of community contributions
3. **Builds Optimized Images** with all merged changes (multi-arch: amd64 + arm64)
4. **Publishes to GitHub Container Registry** (ghcr.io) for easy deployment

This gives you access to bug fixes, new features, and improvements from the Dokploy community before they're officially merged.

## Key Features

### Automated PR Integration
- Daily automated builds that merge your chosen PRs
- Configurable list of PRs to include
- Conflict detection and reporting
- Build summaries with merge status
- Multi-architecture support (amd64, arm64)

### Docker Compose Based Installation
- Generates `docker-compose.yml` for complete stack visibility
- Generates `.env` file for easy configuration
- Standard docker-compose commands work directly
- Easy to modify, maintain, and troubleshoot

### Enterprise-Grade Installation Script
- Clean, modular, DRY codebase
- Comprehensive error handling
- Support for various Linux distributions
- Proxmox LXC container detection
- WSL compatibility checks
- Backup and restore functionality
- Status monitoring commands

### Production Ready
- Docker Swarm orchestration
- PostgreSQL database with persistence and health checks
- Redis caching layer with health checks
- Traefik reverse proxy with HTTPS (optional)
- Automatic SSL certificate management with Let's Encrypt

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Workflow                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Clone upstream Dokploy/dokploy (canary branch)              │
│                          ↓                                       │
│  2. Fetch configured PRs from upstream repository               │
│                          ↓                                       │
│  3. Merge PRs sequentially (skip conflicts)                     │
│                          ↓                                       │
│  4. Pin pnpm to v9.x for compatibility                          │
│                          ↓                                       │
│  5. Build Docker images (amd64 + arm64)                         │
│                          ↓                                       │
│  6. Push to ghcr.io/amirhmoradi/dokploy-enhanced                │
│                          ↓                                       │
│  7. Generate build report and summary                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

Install Dokploy Enhanced on your VPS with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

After installation, access Dokploy at `http://YOUR_SERVER_IP:3000`

## Installation Guide

### Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| RAM | 2 GB | 4 GB+ |
| Disk Space | 30 GB | 50 GB+ |
| OS | Linux (Ubuntu, Debian, CentOS, etc.) | Ubuntu 22.04 LTS |
| Architecture | x86_64, arm64 | x86_64 |

**Network Requirements:**
- Port 80 (HTTP) - for Traefik
- Port 443 (HTTPS) - for Traefik
- Port 3000 (Dokploy Web UI)

### Basic Installation

```bash
# Download and run the installer
curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

The installer will:
1. Check system requirements
2. Install Docker and Docker Compose if not present
3. Initialize Docker Swarm
4. Create required networks
5. Generate configuration files (`.env`, `docker-compose.yml`)
6. Deploy PostgreSQL, Redis, Dokploy, and Traefik
7. Display access information and credentials

### Advanced Configuration

#### Custom Port
```bash
DOKPLOY_PORT=8080 curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

#### Specific Version
```bash
DOKPLOY_VERSION=20241216 curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

#### Custom Advertise Address
```bash
ADVERTISE_ADDR=192.168.1.100 curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

#### Skip Traefik (if you have your own reverse proxy)
```bash
SKIP_TRAEFIK=true curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

#### Custom PostgreSQL Password
```bash
POSTGRES_PASSWORD=mysecretpassword curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

#### Force Installation (skip confirmations)
```bash
FORCE=true curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOKPLOY_VERSION` | Docker image tag to use | `latest` |
| `DOKPLOY_PORT` | Web interface port | `3000` |
| `DOKPLOY_REGISTRY` | Docker registry | `ghcr.io/amirhmoradi` |
| `DOKPLOY_IMAGE` | Docker image name | `dokploy-enhanced` |
| `DOKPLOY_DATA_DIR` | Data directory path | `/etc/dokploy` |
| `ADVERTISE_ADDR` | Docker Swarm advertise address | Auto-detected |
| `SKIP_DOCKER_INSTALL` | Skip Docker installation | `false` |
| `SKIP_TRAEFIK` | Skip Traefik installation | `false` |
| `POSTGRES_PASSWORD` | Custom PostgreSQL password | Auto-generated |
| `FORCE` | Force installation with warnings | `false` |
| `DEBUG` | Enable debug output | `false` |

## Configuration Files

After installation, all configuration is stored in `/etc/dokploy/`:

```
/etc/dokploy/
├── .env                    # Environment variables (edit this!)
├── docker-compose.yml      # Complete stack definition
├── install-info.json       # Installation metadata
└── traefik/
    ├── traefik.yml         # Traefik configuration
    ├── dynamic/            # Dynamic Traefik configs
    └── acme/               # Let's Encrypt certificates
```

### Editing Configuration

To change settings after installation:

1. Edit the `.env` file:
   ```bash
   nano /etc/dokploy/.env
   ```

2. Apply changes:
   ```bash
   ./install.sh restart
   # or directly with docker-compose:
   cd /etc/dokploy && docker compose up -d
   ```

### Example .env File

```bash
# Docker Registry
DOKPLOY_REGISTRY=ghcr.io/amirhmoradi
DOKPLOY_IMAGE=dokploy-enhanced
DOKPLOY_VERSION=latest

# Network
ADVERTISE_ADDR=192.168.1.100
DOKPLOY_PORT=3000
NETWORK_NAME=dokploy-network

# Data Directory
DATA_DIR=/etc/dokploy

# PostgreSQL
POSTGRES_VERSION=16
POSTGRES_USER=dokploy
POSTGRES_DB=dokploy
POSTGRES_PASSWORD=your-secure-password

# Redis
REDIS_VERSION=7

# Traefik
TRAEFIK_VERSION=v3.1.6
SKIP_TRAEFIK=false
```

## Commands Reference

The installation script supports multiple commands:

### Install
```bash
./install.sh install
# or
curl -sSL <url> | bash
```

### Update
Pull latest images and recreate containers:
```bash
./install.sh update
```

### Start
Start all services:
```bash
./install.sh start
```

### Stop
Stop all services:
```bash
./install.sh stop
```

### Restart
Restart all services:
```bash
./install.sh restart
```

### Status
Show current status of all services:
```bash
./install.sh status
```

### Logs
```bash
# View recent logs for all services
./install.sh logs

# Follow logs in real-time
./install.sh logs -f

# Logs for specific service
./install.sh logs dokploy
./install.sh logs postgres -f
```

### Backup
```bash
./install.sh backup
```

### Migrate
Migrate from official Dokploy to Dokploy Enhanced:
```bash
./install.sh migrate
```

### Uninstall
```bash
./install.sh uninstall
```

### Help
```bash
./install.sh help
```

## Migration from Official Dokploy

If you have an existing installation from the [official Dokploy](https://dokploy.com) install script, you can migrate to Dokploy Enhanced while preserving all your data.

### What Gets Migrated

The migration process preserves:
- **PostgreSQL database** (all your projects, users, settings)
- **Redis data** (sessions, cache)
- **Configuration files** (`/etc/dokploy`)
- **Docker volumes** (`dokploy-postgres`, `dokploy-redis`)

### Migration Process

1. **Run the migrate command:**
   ```bash
   curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh -o install.sh
   chmod +x install.sh
   ./install.sh migrate
   ```

2. **The migration will:**
   - Detect your existing Dokploy installation
   - Extract configuration (port, PostgreSQL password, etc.)
   - Create a backup of current state
   - Stop Docker Swarm services
   - Generate new docker-compose.yml and .env files
   - Start services using docker-compose
   - Verify the migration was successful

3. **After migration, you'll have:**
   - Editable `.env` file for configuration
   - `docker-compose.yml` for full stack visibility
   - Standard docker-compose commands
   - Enhanced Dokploy image with merged community PRs

### Pre-Migration Checklist

Before migrating, ensure:
- [ ] You have root access
- [ ] You have a recent backup (migration creates one automatically)
- [ ] Your Dokploy services are running (`docker service ls`)
- [ ] You can access your current Dokploy instance

### Rollback

If migration fails, you can restore from the pre-migration backup:

```bash
# Backup location is shown during migration, e.g.:
# /var/backups/dokploy/pre_migration_20241217_120000

# Stop new services
./install.sh stop

# Restore old services manually using the backup JSON files
# Or contact support for assistance
```

### Differences After Migration

| Aspect | Official Dokploy | Dokploy Enhanced |
|--------|------------------|------------------|
| Service Management | Docker Swarm services | docker-compose |
| Configuration | Environment variables at runtime | `.env` file |
| Stack Visibility | `docker service ls` | `docker-compose.yml` |
| Image Source | `dokploy/dokploy` | `ghcr.io/amirhmoradi/dokploy-enhanced` |
| Updates | Re-run official install | `./install.sh update` |
| Community PRs | Not included | Automatically merged |

## Docker Compose

Since version 2.0.0, the installation uses docker-compose for better visibility and maintenance.

### Direct Docker Compose Commands

You can use standard docker-compose commands directly:

```bash
cd /etc/dokploy

# View status
docker compose ps

# View logs
docker compose logs -f

# Restart a specific service
docker compose restart dokploy

# Pull latest images
docker compose pull

# Recreate containers
docker compose up -d
```

### Generated docker-compose.yml

The installer generates a complete `docker-compose.yml` with:

- **dokploy**: Main application container
- **postgres**: PostgreSQL database with health checks
- **redis**: Redis cache with health checks
- **traefik**: Reverse proxy (optional, via profiles)

### Traefik Profile

Traefik is optional and controlled via docker-compose profiles:

```bash
# Start with Traefik
docker compose --profile traefik up -d

# Start without Traefik
docker compose up -d
```

## GitHub Actions Workflow

The repository includes an automated GitHub Actions workflow that runs daily.

### Configuring PR Merges

1. Go to your repository **Settings** > **Secrets and variables** > **Actions**
2. Click **Variables** tab
3. Create a new repository variable:
   - **Name:** `PR_NUMBERS_TO_MERGE`
   - **Value:** Comma-separated PR numbers (e.g., `1234,5678,9012`)

### Manual Workflow Triggers

You can manually trigger a build from the Actions tab:

1. Go to **Actions** > **Auto-Merge PRs and Build Enhanced Dokploy**
2. Click **Run workflow**
3. Configure options:
   - **PR numbers:** Override the default PR list
   - **Dokploy branch:** Choose `canary` or `main`
   - **Skip build:** Test merge without building

### Build Configuration

The workflow automatically:

- **Pins pnpm to v9.x** - Matches upstream Dokploy for compatibility
- **Bypasses corepack signature verification** - Fixes build issues
- **Uses architecture-specific caches** - Optimizes multi-arch builds
- **Builds for amd64 and arm64** - Supports most server architectures

### Image Tags

| Tag | Description |
|-----|-------------|
| `latest` | Most recent build |
| `YYYYMMDD` | Date-based version (e.g., `20241217`) |
| `YYYYMMDD-amd64` | Architecture-specific |
| `YYYYMMDD-arm64` | Architecture-specific |
| `canary` | Built from canary branch |

## Docker Images

Pull the enhanced Dokploy image:

```bash
# Latest version
docker pull ghcr.io/amirhmoradi/dokploy-enhanced:latest

# Specific date
docker pull ghcr.io/amirhmoradi/dokploy-enhanced:20241217

# Architecture-specific
docker pull ghcr.io/amirhmoradi/dokploy-enhanced:20241217-amd64
docker pull ghcr.io/amirhmoradi/dokploy-enhanced:20241217-arm64
```

### Manual Docker Compose Setup

If you prefer to set up manually without the install script:

```yaml
version: '3.8'

services:
  dokploy:
    image: ghcr.io/amirhmoradi/dokploy-enhanced:latest
    container_name: dokploy
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/dokploy:/etc/dokploy
      - dokploy-docker:/root/.docker
    environment:
      - ADVERTISE_ADDR=your-server-ip
    depends_on:
      - postgres
      - redis

  postgres:
    image: postgres:16
    container_name: dokploy-postgres
    restart: unless-stopped
    volumes:
      - dokploy-postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=dokploy
      - POSTGRES_DB=dokploy
      - POSTGRES_PASSWORD=your-secure-password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dokploy -d dokploy"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7
    container_name: dokploy-redis
    restart: unless-stopped
    volumes:
      - dokploy-redis:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  dokploy-docker:
  dokploy-postgres:
  dokploy-redis:
```

## Backup and Restore

### Creating Backups

```bash
# Using the install script
./install.sh backup

# Backups are stored in /var/backups/dokploy/
```

### Manual Backup

```bash
mkdir -p /var/backups/dokploy
# Backup PostgreSQL
docker run --rm -v dokploy-postgres:/data -v /var/backups/dokploy:/backup alpine tar czf /backup/postgres.tar.gz -C /data .
# Backup Redis
docker run --rm -v dokploy-redis:/data -v /var/backups/dokploy:/backup alpine tar czf /backup/redis.tar.gz -C /data .
# Backup configuration
cp -r /etc/dokploy /var/backups/dokploy/config
```

### Automated Backups

Add to crontab for daily backups at 2 AM:

```bash
crontab -e
# Add this line:
0 2 * * * /etc/dokploy/install.sh backup 2>&1 | logger -t dokploy-backup
```

## Troubleshooting

### Check Service Status

```bash
./install.sh status
# or
cd /etc/dokploy && docker compose ps
```

### View Logs

```bash
# All services
./install.sh logs -f

# Specific service
./install.sh logs dokploy -f
docker compose -f /etc/dokploy/docker-compose.yml logs postgres
```

### Port Already in Use

```bash
# Find what's using the port
ss -tulnp | grep :3000

# Stop the conflicting service
systemctl stop <service-name>
```

### Docker Swarm Issues

```bash
# Check swarm status
docker info | grep Swarm

# Leave existing swarm
docker swarm leave --force

# Re-initialize
docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
```

### Database Connection Issues

```bash
# Check PostgreSQL logs
docker compose -f /etc/dokploy/docker-compose.yml logs postgres

# Check PostgreSQL health
docker exec dokploy-postgres pg_isready -U dokploy -d dokploy
```

### Restart Everything

```bash
./install.sh restart
# or
cd /etc/dokploy && docker compose down && docker compose up -d
```

### Reset Installation

```bash
# Complete reset (WARNING: deletes all data)
./install.sh uninstall
./install.sh install
```

### Proxmox LXC Containers

If running in Proxmox LXC:
1. Enable nesting in container options
2. Enable keyctl feature
3. The installer works normally in unprivileged LXC with proper configuration

### WSL Users

WSL has limitations with Docker networking. For production use, deploy on a proper Linux server or VM.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

### Suggesting PRs to Merge

If you know of valuable community PRs that should be included, please:
1. Open an issue with the PR numbers
2. Explain why they should be included
3. Note any potential conflicts or dependencies

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Dokploy](https://github.com/Dokploy/dokploy) - The original open-source PaaS
- [Docker](https://www.docker.com/) - Container platform
- [Traefik](https://traefik.io/) - Cloud-native reverse proxy
- All contributors to the Dokploy ecosystem

---

## Version History

| Version | Changes |
|---------|---------|
| 2.0.0 | Complete rewrite using docker-compose, .env file generation, new start/stop/restart commands |
| 1.0.0 | Initial release with Docker Swarm services |

---

## Keywords

Dokploy, PaaS, Platform as a Service, self-hosted, Docker, docker-compose, deployment, Vercel alternative, Netlify alternative, Heroku alternative, container orchestration, DevOps, CI/CD, automated deployment, Docker Swarm, Traefik, PostgreSQL, Redis, open source, infrastructure, cloud, VPS deployment, self-hosting, application deployment, web hosting, server management

---

<p align="center">
  <strong>Dokploy Enhanced</strong> - Community-Powered Deployment Platform<br>
  <a href="https://github.com/amirhmoradi/dokploy-enhanced">GitHub</a> |
  <a href="https://github.com/amirhmoradi/dokploy-enhanced/issues">Issues</a> |
  <a href="https://github.com/amirhmoradi/dokploy-enhanced/actions">Builds</a>
</p>
