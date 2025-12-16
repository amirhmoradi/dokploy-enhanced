# Dokploy Enhanced

[![Auto Merge and Build](https://github.com/amirhmoradi/dokploy-enhanced/actions/workflows/auto-merge-build.yml/badge.svg)](https://github.com/amirhmoradi/dokploy-enhanced/actions/workflows/auto-merge-build.yml)
[![Docker Image](https://img.shields.io/badge/docker-ghcr.io%2Famirhmoradi%2Fdokploy--enhanced-blue)](https://ghcr.io/amirhmoradi/dokploy-enhanced)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Dokploy Enhanced** is an automated, enhanced distribution of [Dokploy](https://github.com/Dokploy/dokploy) - the open-source, self-hosted Platform as a Service (PaaS) alternative to Vercel, Netlify, and Heroku. This project automatically merges community pull requests, builds optimized Docker images, and provides an enterprise-grade installation experience.

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
- [Commands Reference](#commands-reference)
- [GitHub Actions Workflow](#github-actions-workflow)
  - [Configuring PR Merges](#configuring-pr-merges)
  - [Manual Workflow Triggers](#manual-workflow-triggers)
  - [Workflow Outputs](#workflow-outputs)
- [Docker Images](#docker-images)
- [Backup and Restore](#backup-and-restore)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Overview

Dokploy Enhanced solves a common challenge in open-source projects: valuable community contributions often wait in pull request queues while users need those fixes and features immediately. This project automatically:

1. **Syncs Daily** with the upstream Dokploy repository
2. **Merges Selected PRs** from a configurable list of community contributions
3. **Builds Optimized Images** with all merged changes
4. **Publishes to GitHub Container Registry** (ghcr.io) for easy deployment

This gives you access to bug fixes, new features, and improvements from the Dokploy community before they're officially merged.

## Key Features

### Automated PR Integration
- Daily automated builds that merge your chosen PRs
- Configurable list of PRs to include
- Conflict detection and reporting
- Build summaries with merge status

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
- PostgreSQL database with persistence
- Redis caching layer
- Traefik reverse proxy with HTTPS
- Automatic SSL certificate management

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
│  4. Build Docker image with merged changes                      │
│                          ↓                                       │
│  5. Push to ghcr.io/amirhmoradi/dokploy-enhanced                │
│                          ↓                                       │
│  6. Generate build report and summary                           │
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
- Port 80 (HTTP)
- Port 443 (HTTPS)
- Port 3000 (Dokploy Web UI)

### Basic Installation

```bash
# Download and run the installer
curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

The installer will:
1. Check system requirements
2. Install Docker if not present
3. Initialize Docker Swarm
4. Create required networks
5. Deploy PostgreSQL, Redis, Dokploy, and Traefik
6. Display access information

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

#### Custom Swarm Configuration
```bash
# Avoid CIDR conflicts with cloud provider VPCs
DOCKER_SWARM_INIT_ARGS="--default-addr-pool 172.20.0.0/16 --default-addr-pool-mask-length 24" \
  curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

#### Dry Run Mode
```bash
DRY_RUN=true curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
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
| `DOCKER_SWARM_INIT_ARGS` | Additional Swarm init arguments | None |
| `SKIP_DOCKER_INSTALL` | Skip Docker installation | `false` |
| `SKIP_TRAEFIK` | Skip Traefik installation | `false` |
| `POSTGRES_PASSWORD` | Custom PostgreSQL password | Auto-generated |
| `BACKUP_DIR` | Backup directory | `/var/backups/dokploy` |
| `DRY_RUN` | Show commands without executing | `false` |
| `FORCE` | Force installation with warnings | `false` |
| `DEBUG` | Enable debug output | `false` |

## Commands Reference

The installation script supports multiple commands:

### Install
```bash
curl -sSL <url> | bash -s -- install
# or simply
curl -sSL <url> | bash
```

### Update
```bash
curl -sSL <url> | bash -s -- update
```

### Uninstall
```bash
curl -sSL <url> | bash -s -- uninstall
```

### Status
```bash
curl -sSL <url> | bash -s -- status
```

### Backup
```bash
curl -sSL <url> | bash -s -- backup
```

### Restore
```bash
curl -sSL <url> | bash -s -- restore /path/to/backup
```

### Logs
```bash
# View recent logs
curl -sSL <url> | bash -s -- logs

# Follow logs in real-time
curl -sSL <url> | bash -s -- logs -f
```

### Help
```bash
curl -sSL <url> | bash -s -- help
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

### Workflow Outputs

Each workflow run generates:
- **Build Summary:** Lists merged/failed PRs
- **Docker Images:** Tagged with `latest`, date, and SHA
- **Version Info:** JSON file embedded in the image

### Image Tags

| Tag | Description |
|-----|-------------|
| `latest` | Most recent build |
| `YYYYMMDD` | Date-based version |
| `sha-XXXXXXX` | Git commit SHA |
| `canary` | Built from canary branch |

## Docker Images

Pull the enhanced Dokploy image:

```bash
# Latest version
docker pull ghcr.io/amirhmoradi/dokploy-enhanced:latest

# Specific date
docker pull ghcr.io/amirhmoradi/dokploy-enhanced:20241216

# Specific commit
docker pull ghcr.io/amirhmoradi/dokploy-enhanced:sha-abc1234
```

### Using with Docker Compose

```yaml
version: '3.8'
services:
  dokploy:
    image: ghcr.io/amirhmoradi/dokploy-enhanced:latest
    ports:
      - "3000:3000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - dokploy-data:/etc/dokploy
    environment:
      - ADVERTISE_ADDR=your-server-ip

volumes:
  dokploy-data:
```

## Backup and Restore

### Creating Backups

```bash
# Using the install script
curl -sSL <url> | bash -s -- backup

# Manual backup
mkdir -p /var/backups/dokploy
docker run --rm -v dokploy-postgres:/data -v /var/backups/dokploy:/backup alpine tar czf /backup/postgres.tar.gz -C /data .
docker run --rm -v dokploy-redis:/data -v /var/backups/dokploy:/backup alpine tar czf /backup/redis.tar.gz -C /data .
cp -r /etc/dokploy /var/backups/dokploy/data
```

### Restoring Backups

```bash
# Using the install script
curl -sSL <url> | bash -s -- restore /var/backups/dokploy/dokploy_backup_20241216_120000
```

### Automated Backups

Add to crontab for daily backups:

```bash
0 2 * * * curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash -s -- backup
```

## Troubleshooting

### Port Already in Use

```bash
# Find what's using port 3000
ss -tulnp | grep :3000

# Stop the conflicting service
systemctl stop <service-name>
```

### Docker Swarm Issues

```bash
# Leave existing swarm
docker swarm leave --force

# Re-initialize
docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
```

### Service Not Starting

```bash
# Check service status
docker service ls
docker service ps dokploy

# View logs
docker service logs dokploy --tail 100
```

### Database Connection Issues

```bash
# Check PostgreSQL service
docker service logs dokploy-postgres --tail 50

# Verify network connectivity
docker network inspect dokploy-network
```

### Proxmox LXC Containers

If running in Proxmox LXC:
1. Enable nesting in container options
2. The installer automatically detects LXC and adds `--endpoint-mode dnsrr`

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

## Keywords

Dokploy, PaaS, Platform as a Service, self-hosted, Docker, deployment, Vercel alternative, Netlify alternative, Heroku alternative, container orchestration, DevOps, CI/CD, automated deployment, Docker Swarm, Traefik, PostgreSQL, Redis, open source, infrastructure, cloud, VPS deployment, self-hosting, application deployment, web hosting, server management

---

<p align="center">
  <strong>Dokploy Enhanced</strong> - Community-Powered Deployment Platform<br>
  <a href="https://github.com/amirhmoradi/dokploy-enhanced">GitHub</a> |
  <a href="https://github.com/amirhmoradi/dokploy-enhanced/issues">Issues</a> |
  <a href="https://github.com/amirhmoradi/dokploy-enhanced/actions">Builds</a>
</p>
