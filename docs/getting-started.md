---
layout: default
title: Getting Started
nav_order: 3
description: "How to fork, configure, and run your own Dokploy Enhanced builds"
permalink: /getting-started/
---

# Getting Started
{: .no_toc }

Set up your own Dokploy Enhanced build in under 10 minutes.
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

## Choose Your Path

| Option | Best For | Time |
|:-------|:---------|:-----|
| [Use Pre-Built Images](#option-1-use-pre-built-images) | Quick start, testing | 2 min |
| [Fork and Customize](#option-2-fork-and-customize) | Production, custom PRs | 10 min |

---

## Option 1: Use Pre-Built Images

Use our pre-built images with curated PR selections.

### One-Line Install

```bash
curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

### What Gets Deployed

| Component | Details |
|:----------|:--------|
| **Dokploy** | Enhanced image with merged PRs |
| **PostgreSQL 16** | Database with persistence |
| **Valkey (Redis)** | Cache layer with AOF persistence |
| **Traefik** | Reverse proxy with HTTPS (optional) |

### Access Your Instance

After installation completes:

```
╔════════════════════════════════════════════════════════════════╗
║                    Installation Complete!                       ║
╠════════════════════════════════════════════════════════════════╣
║  Access Dokploy at: http://YOUR_SERVER_IP:3000                 ║
║  Configuration: /etc/dokploy/.env                              ║
╚════════════════════════════════════════════════════════════════╝
```

{: .note }
> This option uses our PR selections. For full control, use Option 2.

---

## Option 2: Fork and Customize

Create your own build with exactly the PRs you want.

### Step 1: Fork the Repository

1. Go to [github.com/amirhmoradi/dokploy-enhanced](https://github.com/amirhmoradi/dokploy-enhanced)
2. Click **Fork** in the top right
3. Keep all default settings
4. Click **Create fork**

### Step 2: Enable GitHub Actions

1. Go to your forked repository
2. Click **Actions** tab
3. Click **I understand my workflows, go ahead and enable them**

### Step 3: Configure Container Registry

GitHub Container Registry (GHCR) needs write permissions:

1. Go to **Settings** → **Actions** → **General**
2. Scroll to **Workflow permissions**
3. Select **Read and write permissions**
4. Click **Save**

### Step 4: Choose Your PRs

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click the **Variables** tab
3. Click **New repository variable**
4. Configure:

| Name | Value |
|:-----|:------|
| `PR_NUMBERS_TO_MERGE` | Comma-separated PR numbers (e.g., `1234,5678,9012`) |

{: .highlight }
> **Finding PRs**: Browse [Dokploy Pull Requests](https://github.com/Dokploy/dokploy/pulls) for features you need. Note the PR numbers.

### Step 5: Trigger Your First Build

1. Go to **Actions** tab
2. Click **Auto-Merge PRs and Build Enhanced Dokploy**
3. Click **Run workflow**
4. Configure:
   - **Branch**: `main`
   - **PR numbers**: Leave empty to use your configured variable
   - **Dokploy branch**: `canary` (recommended) or `main`
5. Click **Run workflow**

The build takes approximately 15-20 minutes.

### Step 6: Deploy Your Build

Once the build completes, deploy using your registry:

```bash
DOKPLOY_REGISTRY=ghcr.io/YOUR_GITHUB_USERNAME \
curl -sSL https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/dokploy-enhanced/main/install.sh | bash
```

Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

---

## Finding Good PRs

### Where to Look

1. **[Open Pull Requests](https://github.com/Dokploy/dokploy/pulls)** — Browse current PRs
2. **[Issues with Linked PRs](https://github.com/Dokploy/dokploy/issues)** — Find PRs that fix specific issues
3. **Community Discussions** — See what others need

### What to Look For

{: .highlight }
> **Good candidates**: Bug fixes, security patches, well-tested features, PRs with positive reviews

{: .warning }
> **Use caution**: Large refactors, breaking changes, PRs with failing tests, very old PRs

### Recommended Evaluation

Before adding a PR:

1. **Read the PR description** — Understand what it does
2. **Check the diff** — Review the code changes
3. **Look at test status** — Ensure CI passes
4. **Read comments** — See maintainer/community feedback
5. **Check for conflicts** — Very old PRs may not merge cleanly

---

## Configuration Options

### Environment Variables

Customize installation with environment variables:

```bash
# Custom port
DOKPLOY_PORT=8080 curl -sSL ... | bash

# Skip Traefik (use your own reverse proxy)
SKIP_TRAEFIK=true curl -sSL ... | bash

# Specific version
DOKPLOY_VERSION=20250110 curl -sSL ... | bash

# Custom PostgreSQL password
POSTGRES_PASSWORD=mysecretpassword curl -sSL ... | bash

# Force mode (skip confirmations)
FORCE=true curl -sSL ... | bash
```

### Full Variable Reference

| Variable | Default | Description |
|:---------|:--------|:------------|
| `DOKPLOY_PORT` | `3000` | Web interface port |
| `DOKPLOY_VERSION` | `latest` | Docker image tag |
| `DOKPLOY_REGISTRY` | `ghcr.io/amirhmoradi` | Docker registry |
| `SKIP_TRAEFIK` | `false` | Skip Traefik installation |
| `POSTGRES_PASSWORD` | Auto-generated | Database password |
| `ADVERTISE_ADDR` | Auto-detected | Docker Swarm address |
| `FORCE` | `false` | Skip confirmations |
| `DEBUG` | `false` | Enable debug output |

---

## Post-Installation

### File Locations

```
/etc/dokploy/
├── .env                    # Configuration (edit this!)
├── docker-compose.yml      # Stack definition
├── install-info.json       # Installation metadata
└── traefik/                # Traefik configuration (if enabled)
```

### Common Commands

```bash
# Check status
./install.sh status

# View logs
./install.sh logs -f

# Restart services
./install.sh restart

# Update to latest
./install.sh update

# Create backup
./install.sh backup
```

---

## Automatic Updates

The GitHub Actions workflow runs daily at 00:00 UTC, automatically:

1. Pulling latest Dokploy changes
2. Merging your configured PRs
3. Building new images
4. Pushing to your registry

To update your deployment:

```bash
cd /etc/dokploy
./install.sh update
```

---

## Troubleshooting

### Build Fails with Merge Conflict

Some PRs may conflict with each other or with upstream changes.

**Solution**: Remove the conflicting PR from your list and try again. Check the build logs to identify which PR caused the conflict.

### Image Not Found

Ensure your container registry is public or properly authenticated.

**Solution**:
1. Go to your GitHub profile → Packages
2. Find your `dokploy-enhanced` package
3. Click **Package settings**
4. Under **Danger Zone**, change visibility to **Public**

### Services Won't Start

Check Docker logs and service status:

```bash
./install.sh logs
docker compose -f /etc/dokploy/docker-compose.yml ps
```

---

## Next Steps

- [Learn about contributing]({% link contributing.md %})
- [View configuration options]({% link configuration.md %})
- [Troubleshooting guide]({% link troubleshooting.md %})
