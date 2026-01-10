---
layout: default
title: Contributing
nav_order: 6
description: "How to contribute to Dokploy and Dokploy Enhanced"
permalink: /contributing/
---

# Contributing
{: .no_toc }

Two ways to make a difference: contribute upstream or improve this project.
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

## Contribution Philosophy

{: .important }
> The best contribution you can make is to **improve Dokploy itself**. This project exists to bridge the gap while PRs await merge—not to replace upstream development.

We strongly encourage:
1. **Contributing to Dokploy first** — Create PRs on the main repository
2. **Using this project second** — Include your PR while waiting for merge
3. **Removing from this project third** — Once merged upstream, remove from your PR list

---

## Contributing to Dokploy

Creating high-quality PRs on Dokploy benefits everyone—including users of Dokploy Enhanced.

### Before You Start

1. **Check existing issues and PRs** — Your idea may already be in progress
2. **Open an issue first** — For large changes, discuss before coding
3. **Read [Dokploy's contributing guide](https://github.com/Dokploy/dokploy/blob/main/CONTRIBUTING.md)**

### Creating a Quality PR

{: .highlight }
> PRs that follow these guidelines are more likely to be merged quickly.

#### 1. Keep It Focused

- **One PR, one feature** — Don't bundle unrelated changes
- **Small is beautiful** — Smaller PRs get reviewed faster
- **Atomic commits** — Each commit should be self-contained

#### 2. Write Good Code

```typescript
// Good: Clear, typed, documented
/**
 * Validates deployment configuration before apply.
 * @param config - The deployment configuration to validate
 * @returns Validation result with any errors
 */
export function validateDeployment(config: DeploymentConfig): ValidationResult {
  // Implementation
}

// Bad: Unclear, untyped, undocumented
export function validate(c) {
  // ???
}
```

#### 3. Include Tests

```typescript
describe('validateDeployment', () => {
  it('should accept valid configurations', () => {
    const config = createValidConfig();
    const result = validateDeployment(config);
    expect(result.valid).toBe(true);
  });

  it('should reject configurations without name', () => {
    const config = { ...createValidConfig(), name: undefined };
    const result = validateDeployment(config);
    expect(result.valid).toBe(false);
    expect(result.errors).toContain('name is required');
  });
});
```

#### 4. Write a Great PR Description

```markdown
## Summary
Brief description of what this PR does.

## Problem
What issue does this solve? Link to issue if applicable.

## Solution
How does this PR solve the problem?

## Testing
How was this tested? Steps to verify.

## Screenshots (if UI changes)
Before/after screenshots.

## Checklist
- [ ] Tests pass
- [ ] Code follows style guidelines
- [ ] Documentation updated (if needed)
```

#### 5. Be Responsive

- Respond to review feedback promptly
- Make requested changes or explain why not
- Keep the PR up-to-date with main branch

### After Your PR is Created

Once your PR is on Dokploy:

1. **Add it to your Enhanced build** — Use the PR immediately
2. **Get community feedback** — Others using Enhanced can test it
3. **Iterate based on feedback** — Fix issues found in production use
4. **Wait for official merge** — Then remove from your PR list

---

## Suggesting PRs for Our Build

Know of a great PR that should be in our default build?

### How to Suggest

1. Open an issue titled **"PR Suggestion: [Brief Description]"**
2. Include:
   - Upstream PR number and link
   - What the PR does
   - Why it should be included
   - Any known issues or conflicts
   - Your testing experience (if any)

### What We Look For

| Criteria | Why It Matters |
|:---------|:---------------|
| **Bug fixes** | High impact, low risk |
| **Security patches** | Critical for production |
| **Well-tested** | Reduces risk of breakage |
| **Community demand** | Benefits many users |
| **Clean code** | Easier to maintain |
| **Positive reviews** | Already vetted by others |

### What We Avoid

- PRs with failing tests
- Large refactors that touch many files
- Breaking changes without migration path
- PRs that conflict with other included PRs
- Very old PRs (may have significant conflicts)

---

## Contributing to This Project

Help improve the build system, documentation, or installation experience.

### Repository Overview

```
dokploy-enhanced/
├── install.sh                    # Installation script (bash)
├── .github/
│   ├── workflows/
│   │   └── auto-merge-build.yml  # Main build workflow
│   └── scripts/                  # Migration conflict resolution
├── docs/                         # This website
└── config/                       # Configuration examples
```

### Areas to Contribute

#### Installation Script

The `install.sh` script handles:
- Docker/Docker Compose installation
- Stack deployment (PostgreSQL, Redis, Traefik, Dokploy)
- Configuration generation
- Backup/restore/migration

**Good contributions**:
- Support for new Linux distributions
- Improved error handling
- New management commands
- Performance optimizations

**Requirements**:
- Use `shellcheck` for linting
- Test with `DRY_RUN=true bash install.sh`
- Follow existing code style

#### Build Workflow

The GitHub Actions workflow handles:
- Upstream syncing
- PR merging with conflict resolution
- Multi-arch Docker builds
- Registry publishing

**Good contributions**:
- Improved conflict resolution
- Build optimization
- Better error reporting
- New trigger options

#### Documentation

This website is built with Jekyll:

**Good contributions**:
- Fixing typos and errors
- Adding examples
- Improving clarity
- New guides and tutorials

### Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/dokploy-enhanced.git
cd dokploy-enhanced

# Test install script
DRY_RUN=true bash install.sh

# Lint shell scripts
shellcheck install.sh

# Run docs locally (requires Ruby)
cd docs
bundle install
bundle exec jekyll serve
```

### Pull Request Process

1. **Fork and branch** — Create a feature branch from `main`
2. **Make changes** — Follow existing code style
3. **Test thoroughly** — Especially for install.sh changes
4. **Write good commits** — Use conventional format (`feat:`, `fix:`, etc.)
5. **Open PR** — Reference any related issues
6. **Respond to feedback** — Make requested changes

### Detailed Guidelines

For complete contribution guidelines, see:

[View CONTRIBUTING.md on GitHub](https://github.com/amirhmoradi/dokploy-enhanced/blob/main/CONTRIBUTING.md){: .btn .btn-primary }

---

## Code of Conduct

Be respectful, constructive, and helpful. We're all here to make Dokploy better.

- **Be kind** — Assume good intentions
- **Be constructive** — Offer solutions, not just criticism
- **Be patient** — Everyone has different experience levels
- **Be inclusive** — Welcome all contributors

---

## Recognition

Contributors are recognized in:
- Git commit history
- Release notes (for significant contributions)
- README acknowledgments (for major features)

Thank you for contributing!
