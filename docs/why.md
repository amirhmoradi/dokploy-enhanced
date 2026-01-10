---
layout: default
title: Why This Project
nav_order: 2
description: "Why Dokploy Enhanced exists and the problems it solves"
permalink: /why/
---

# Why Dokploy Enhanced Exists
{: .no_toc }

Understanding the gap between community contributions and production needs.
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

## The Open Source Paradox

Dokploy is a fantastic open-source project. It provides a self-hosted alternative to platforms like Vercel, Netlify, and Heroku. The community is active, contributions flow in regularly, and the core team works hard.

But there's a paradox common to many open-source projects:

{: .important }
> **The more successful a project becomes, the slower it moves.**

As projects grow, maintainers face increasing demands:
- More PRs to review
- More issues to triage
- More features to consider
- More users to support
- More infrastructure to maintain

Something has to give. Usually, it's PR merge velocity.

---

## The PR Backlog Problem

### What We've Observed

Community members submit excellent PRs that:
- Fix critical bugs affecting production deployments
- Add features users have requested for months
- Improve performance and security
- Enhance the developer experience

Yet these PRs often sit in the queue for **weeks or months**, even when:
- The code is high-quality
- Tests pass
- Multiple community members request the feature
- The PR has positive reviews

### Why This Happens

We're not criticizing the Dokploy maintainers—they're doing their best with limited resources. The reality is:

| Challenge | Impact |
|:----------|:-------|
| **Limited maintainer time** | PRs queue up faster than they can be reviewed |
| **Risk aversion** | Breaking changes are scary, so safe PRs wait too |
| **Priority mismatches** | Maintainer priorities may differ from user needs |
| **Review bottlenecks** | Only a few people can approve merges |

---

## The Enterprise Gap

Organizations running Dokploy in production often need features that the community has built but haven't been merged:

### Common Unmerged Enterprise Features

- **Advanced monitoring** — Better observability and alerting
- **Enhanced security** — SSO, RBAC improvements, audit logging
- **Scalability fixes** — Multi-node improvements, connection pooling
- **Performance optimizations** — Caching, query optimization
- **Integration features** — Additional providers, webhooks, APIs

These features exist as PRs. They're tested. They work. But they're not in the official release.

---

## Our Philosophy

### We Don't Compete—We Bridge

Dokploy Enhanced is **not** a fork that competes with Dokploy. We are a build system that:

1. **Respects upstream** — We pull from Dokploy daily
2. **Adds, never removes** — We only merge additional PRs
3. **Stays synchronized** — When PRs are officially merged, we stop including them
4. **Encourages contribution** — We want PRs to land upstream

### We Believe In

{: .highlight }
> **User autonomy** — You should decide which features you need, not wait for someone else's timeline.

{: .highlight }
> **Transparency** — You can see exactly which PRs are included and review them yourself.

{: .highlight }
> **Simplicity** — Fork, configure, deploy. No complex infrastructure required.

{: .highlight }
> **Community** — The best features come from users solving real problems.

---

## Who Is This For?

### Perfect For

- **Production deployments** that need specific bug fixes now
- **Enterprise teams** requiring features before official release
- **Power users** who want to customize their Dokploy stack
- **Organizations** with compliance requirements to build from source
- **Contributors** who want to use their own PRs immediately

### Not For

- Users who prefer to wait for official releases
- Those uncomfortable reviewing PRs before inclusion
- Deployments requiring official vendor support

---

## The Contribution Cycle

We encourage a healthy contribution cycle:

```
┌──────────────────────────────────────────────────────────────┐
│                                                               │
│    1. You encounter a bug or need a feature                  │
│                          ↓                                    │
│    2. You (or someone) creates a PR on Dokploy               │
│                          ↓                                    │
│    3. While waiting for merge, add it to your Enhanced build │
│                          ↓                                    │
│    4. Use the feature in production immediately              │
│                          ↓                                    │
│    5. When officially merged, it's removed from your list    │
│                          ↓                                    │
│    6. You're always on the latest official + your PRs        │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

This way:
- You get what you need now
- Dokploy gets the contribution
- The community benefits from your feedback
- Everyone wins

---

## Common Questions

### Isn't this just a hostile fork?

No. We:
- Don't maintain our own codebase
- Pull from upstream daily
- Don't compete for users
- Actively encourage upstream contribution

### What if a PR breaks something?

You control which PRs to include. We recommend:
- Reviewing PRs before adding them
- Testing in staging before production
- Starting with widely-requested, well-reviewed PRs

### Will this fragment the community?

We don't think so. Users of Enhanced:
- Still use Dokploy (just with additional PRs)
- Still report issues upstream
- Still contribute to the main project
- Are often the most engaged community members

### What happens when PRs get merged upstream?

You simply remove them from your `PR_NUMBERS_TO_MERGE` list. The next build will use the official version.

---

## The Bottom Line

{: .note }
> Dokploy Enhanced exists because **waiting months for a bug fix that already exists as a PR is frustrating**. We provide a legitimate, transparent way to use community contributions before they're officially released—while still supporting and contributing to the upstream project.

[Get Started →]({% link getting-started.md %}){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 }
