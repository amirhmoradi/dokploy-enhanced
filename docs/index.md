---
layout: default
title: Home
nav_order: 1
description: "Dokploy Enhanced - Community-powered Dokploy with faster PR integration and enterprise features"
permalink: /
---

# Dokploy Enhanced
{: .fs-9 }

Get the features you need today, not months from now.
{: .fs-6 .fw-300 }

[Get Started](#quick-start){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/amirhmoradi/dokploy-enhanced){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## The Problem

**Dokploy is an amazing open-source PaaS**, but like many open-source projects, it faces challenges:

{: .warning }
> **Slow PR Merges** — Valuable community contributions often wait weeks or months in the review queue. Bug fixes and features you need today might not land until next quarter.

{: .warning }
> **Selective Prioritization** — Some PRs get fast-tracked while others languish, regardless of community demand or code quality.

{: .warning }
> **Missing Enterprise Features** — Production-ready features like advanced monitoring, multi-node clustering, and enhanced security often come from the community but aren't prioritized.

---

## The Solution

**Dokploy Enhanced** is an automated build system that lets you create your own Dokploy distribution with the PRs *you* choose.

{: .highlight }
> **Daily Synced** — Automatically pulls the latest changes from upstream Dokploy every day.

{: .highlight }
> **Your PRs, Your Build** — Configure which community PRs to include. Get bug fixes and features immediately.

{: .highlight }
> **Production Ready** — Multi-architecture Docker images (amd64 + arm64) published to GitHub Container Registry.

{: .highlight }
> **Zero Maintenance** — GitHub Actions handles everything. Set it and forget it.

---

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                  Daily Automated Build                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   1. Clone upstream Dokploy (canary branch)                 │
│                          ↓                                   │
│   2. Fetch your configured PRs                              │
│                          ↓                                   │
│   3. Merge PRs (with intelligent conflict resolution)       │
│                          ↓                                   │
│   4. Build multi-arch Docker images                         │
│                          ↓                                   │
│   5. Push to your GitHub Container Registry                 │
│                          ↓                                   │
│   6. Deploy to your servers                                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Option 1: Use Our Pre-Built Images

Install Dokploy Enhanced with our curated PR selections:

```bash
curl -sSL https://raw.githubusercontent.com/amirhmoradi/dokploy-enhanced/main/install.sh | bash
```

Access Dokploy at `http://YOUR_SERVER_IP:3000`

### Option 2: Build Your Own (Recommended)

1. **Fork this repository** to your GitHub account

2. **Configure your PRs** — Go to Settings → Secrets and Variables → Actions → Variables
   - Create `PR_NUMBERS_TO_MERGE` with comma-separated PR numbers
   - Example: `1234,5678,9012`

3. **Enable GitHub Actions** — The workflow runs daily at 00:00 UTC

4. **Use your images**:
   ```bash
   DOKPLOY_REGISTRY=ghcr.io/YOUR_USERNAME \
   curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/dokploy-enhanced/main/install.sh | bash
   ```

[Detailed Setup Guide →]({% link getting-started.md %}){: .btn .btn-outline }

---

## Why Fork?

| Approach | Pros | Cons |
|:---------|:-----|:-----|
| **Use our images** | Zero setup, immediate access | Limited to our PR selection |
| **Fork and customize** | Full control over included PRs, your own registry | Initial 5-minute setup |

We recommend forking because:

- **You control what goes in** — Only include PRs you've reviewed and trust
- **Your registry, your images** — No dependency on our infrastructure
- **Enterprise compliance** — Build from source for audit requirements

---

## Community-Driven

This project exists to bridge the gap between Dokploy's amazing community and users who need those contributions now.

### Contributing to Dokploy

The best way to improve Dokploy is to contribute upstream:

1. Create high-quality PRs on [Dokploy/dokploy](https://github.com/Dokploy/dokploy)
2. Follow their contribution guidelines
3. Once your PR is ready, reference it in this project's PR list

[Learn More →]({% link contributing.md %}){: .btn .btn-outline }

### Contributing Here

Help improve the build system, documentation, or installation scripts.

[View CONTRIBUTING.md](https://github.com/amirhmoradi/dokploy-enhanced/blob/main/CONTRIBUTING.md){: .btn .btn-outline }

---

## What's Included

Our default build includes carefully selected PRs that add:

- Bug fixes awaiting merge
- Performance improvements
- UI/UX enhancements
- Enterprise-ready features

Check the [GitHub repository](https://github.com/amirhmoradi/dokploy-enhanced) for the current PR list.

---

<div class="d-flex flex-justify-around flex-wrap">
  <div class="text-center p-4">
    <h3 class="fs-5">Daily Builds</h3>
    <p class="text-grey-dk-000">Automated sync with upstream</p>
  </div>
  <div class="text-center p-4">
    <h3 class="fs-5">Multi-Arch</h3>
    <p class="text-grey-dk-000">amd64 + arm64 support</p>
  </div>
  <div class="text-center p-4">
    <h3 class="fs-5">Open Source</h3>
    <p class="text-grey-dk-000">MIT License</p>
  </div>
</div>
