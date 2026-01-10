---
layout: default
title: Migration
nav_order: 7
description: "Migrate from official Dokploy to Dokploy Enhanced"
permalink: /migration/
---

# Migration Guide
{: .no_toc }

Migrate from official Dokploy while preserving all your data.
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

## Overview

If you have an existing installation from the official Dokploy install script, you can migrate to Dokploy Enhanced while preserving:

- All projects and deployments
- User accounts and settings
- Database content
- Redis cache and sessions
- Configuration files

---

## Pre-Migration Checklist

Before migrating, verify:

- [ ] Root/sudo access available
- [ ] Current Dokploy services are running
- [ ] Current instance is accessible
- [ ] Sufficient disk space for backup (~2x current data)
- [ ] Recent backup exists (migration creates one, but be safe)

### Verify Current Installation

```bash
# Check Docker Swarm services
docker service ls

# Expected output includes:
# dokploy, dokploy-postgres, dokploy-redis, dokploy-traefik
```

```bash
# Verify Dokploy is accessible
curl -s http://localhost:3000 | head -5
```

---

## Migration Process

### Step 1: Download the Script

```bash
curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh -o install.sh
chmod +x install.sh
```

### Step 2: Run Migration

```bash
./install.sh migrate
```

### What Happens

The migration will:

1. **Detect** your existing Dokploy installation
2. **Extract** current configuration (port, passwords, etc.)
3. **Backup** current state to `/var/backups/dokploy/pre_migration_*`
4. **Stop** Docker Swarm services
5. **Generate** new `docker-compose.yml` and `.env` files
6. **Start** services using docker-compose
7. **Verify** the migration was successful

### Example Output

```
╔══════════════════════════════════════════════════════════════════╗
║                 Dokploy Enhanced Migration                        ║
╠══════════════════════════════════════════════════════════════════╣
║  Detected existing Dokploy installation                          ║
║                                                                   ║
║  Current configuration:                                           ║
║    - Port: 3000                                                   ║
║    - PostgreSQL: dokploy-postgres                                 ║
║    - Redis: dokploy-redis                                         ║
║                                                                   ║
║  Creating backup...                                               ║
║  Backup saved to: /var/backups/dokploy/pre_migration_20250110    ║
║                                                                   ║
║  Stopping Swarm services...                                       ║
║  Generating new configuration...                                  ║
║  Starting docker-compose services...                              ║
║                                                                   ║
║  ✓ Migration complete!                                            ║
║                                                                   ║
║  Access Dokploy at: http://YOUR_IP:3000                          ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## What Changes

### Before (Official Dokploy)

| Aspect | Details |
|:-------|:--------|
| **Management** | Docker Swarm services |
| **Configuration** | Runtime environment variables |
| **Visibility** | `docker service ls` |
| **Image** | `dokploy/dokploy` |
| **Updates** | Re-run official install script |

### After (Dokploy Enhanced)

| Aspect | Details |
|:-------|:--------|
| **Management** | docker-compose |
| **Configuration** | Editable `.env` file |
| **Visibility** | `docker-compose.yml` |
| **Image** | `ghcr.io/.../dokploy-enhanced` |
| **Updates** | `./install.sh update` |

---

## What Stays the Same

{: .highlight }
> All your data is preserved during migration.

- **Database** — All PostgreSQL data (projects, users, settings)
- **Cache** — All Redis data (sessions, cache)
- **Volumes** — `dokploy-postgres` and `dokploy-redis` volumes
- **Port** — Same port as before (default: 3000)
- **Credentials** — Database passwords preserved

---

## Post-Migration Verification

### Check Services

```bash
./install.sh status
```

### Verify Access

Open `http://YOUR_IP:3000` and log in with your existing credentials.

### Check Logs

```bash
./install.sh logs -f
```

---

## Rollback

If migration fails or you want to revert:

### Step 1: Stop New Services

```bash
./install.sh stop
# or
cd /etc/dokploy && docker compose down
```

### Step 2: Restore Swarm Services

The backup includes service definitions. Contact support or manually recreate:

```bash
# Example: Re-create Dokploy Swarm service
docker service create \
  --name dokploy \
  --publish 3000:3000 \
  # ... (see backup for full config)
```

### Step 3: Verify Restoration

```bash
docker service ls
curl http://localhost:3000
```

---

## Troubleshooting

### Migration Fails at Backup Stage

**Cause**: Insufficient disk space or permissions.

**Solution**:
```bash
# Check disk space
df -h /var/backups

# Ensure directory exists
sudo mkdir -p /var/backups/dokploy
sudo chmod 755 /var/backups/dokploy
```

### Services Don't Start After Migration

**Cause**: Port conflict or network issue.

**Solution**:
```bash
# Check what's using the port
ss -tulnp | grep :3000

# Check Docker networks
docker network ls
docker network inspect dokploy-network
```

### Database Connection Errors

**Cause**: Password mismatch or PostgreSQL not ready.

**Solution**:
```bash
# Check PostgreSQL logs
docker compose -f /etc/dokploy/docker-compose.yml logs postgres

# Verify password in .env matches what was extracted
cat /etc/dokploy/.env | grep POSTGRES
```

### Can't Login After Migration

**Cause**: Session cache was cleared.

**Solution**: This is normal. Simply log in again with your existing credentials.

---

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting Guide]({% link troubleshooting.md %})
2. Review logs: `./install.sh logs`
3. Open an issue on [GitHub](https://github.com/amirhmoradi/dokploy-enhanced/issues)

Include:
- Migration output
- Relevant log excerpts
- Your OS and Docker versions
