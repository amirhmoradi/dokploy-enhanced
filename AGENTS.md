# AGENTS.md

> Universal guidance for AI coding agents. Compatible with [GitHub Copilot](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/), [OpenAI Codex](https://developers.openai.com/codex/guides/agents-md/), Cursor, and other agents following the [AGENTS.md standard](https://agents.md).

## Project Summary

**Dokploy Enhanced** - Automated distribution of Dokploy PaaS with community PR integration.

| Attribute | Value |
|-----------|-------|
| Language | Bash (install.sh), Python (migration scripts), YAML (workflows) |
| Stack | Docker, Docker Compose, Docker Swarm, PostgreSQL 16, Valkey/Redis |
| CI/CD | GitHub Actions |
| Registry | `ghcr.io/amirhmoradi/dokploy-enhanced` |

## Project Structure

```
dokploy-enhanced/
├── install.sh                    # Main CLI (1,700+ lines bash)
├── .github/
│   ├── workflows/
│   │   └── auto-merge-build.yml  # Daily build workflow (900+ lines)
│   └── scripts/
│       └── drizzle_migration_manager.py  # Comprehensive migration conflict resolver
├── config/
│   └── example.env
├── docs/                         # GitHub Pages website (Just the Docs theme)
│   ├── _config.yml               # Jekyll configuration
│   ├── index.md                  # Homepage with value proposition
│   ├── why.md                    # Project motivation
│   ├── getting-started.md        # Fork & customize guide
│   ├── contributing.md           # Dual contribution paths
│   ├── assets/                   # Static assets (logo, CSS)
│   ├── _sass/custom/             # Custom SCSS styles
│   ├── tasks/                    # Task management (excluded from build)
│   └── prds/                     # PRDs (excluded from build)
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

## Commands

```bash
# Lint shell script
shellcheck install.sh

# Dry-run installation test
DRY_RUN=true bash install.sh

# Test GitHub Actions locally
act -W .github/workflows/auto-merge-build.yml

# Drizzle migration manager
python3 .github/scripts/drizzle_migration_manager.py <drizzle_dir> --mode fix --verbose
python3 .github/scripts/drizzle_migration_manager.py <drizzle_dir> --mode validate
python3 .github/scripts/drizzle_migration_manager.py <drizzle_dir> --mode cleanup
```

## Testing

- **Shell scripts**: Run `shellcheck install.sh` before committing
- **Dry-run mode**: Use `DRY_RUN=true bash install.sh` to test without side effects
- **Migration manager**: Use `--dry-run` and `--mode validate` for safe testing
- **Workflow changes**: Use [nektos/act](https://github.com/nektos/act) for local testing

## Code Style

### Bash (install.sh)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Constants: UPPER_SNAKE_CASE
readonly DATA_DIR="/etc/dokploy"
readonly DEFAULT_PORT=3000

# Functions: snake_case with single responsibility
check_requirements() {
    local missing_deps=()
    # ...
}

# Local variables: lowercase
local result
local port
```

### Python (.github/scripts/)

```python
#!/usr/bin/env python3
"""Module docstring explaining purpose."""

def merge_journals(upstream_path: str, pr_path: str) -> dict:
    """Merge two Drizzle journal files."""
    pass
```

### YAML

- 2-space indentation
- Quote ambiguous strings
- Comment non-obvious logic

## Git Workflow

- **Branch**: Create from `main`
- **Commits**: Use conventional format
  - `feat:` new features
  - `fix:` bug fixes
  - `docs:` documentation
  - `chore:` maintenance
- **PR titles**: Same format as commits

## Boundaries

### Always Do

- Run `shellcheck` on bash changes
- Test with `DRY_RUN=true` before committing install.sh changes
- Update README.md when adding new features or options
- **Update AGENTS.md and CLAUDE.md when making any project changes** (new files, commands, structure, or conventions)
- **Update docs/ when user-facing features change**
- Create a PRD in `docs/prds/` before implementing major features
- Use conventional commit messages
- Quote variables in bash: `"${VAR}"`

### Ask First

- Modifying the GitHub Actions workflow triggers
- Adding new environment variables to install.sh
- Changing Docker image tags or registry
- Modifying Drizzle migration handling logic

### Never Do

- Commit secrets, passwords, or API keys
- Modify `LICENSE` file
- Push directly to `main` branch
- Remove safety checks (`set -euo pipefail`)
- Skip shellcheck errors with `# shellcheck disable`
- Hardcode IP addresses or hostnames

## Key Files

| File | Purpose |
|------|---------|
| `install.sh` | User-facing installation CLI |
| `.github/workflows/auto-merge-build.yml` | Daily sync, merge, and build |
| `.github/scripts/drizzle_migration_manager.py` | Drizzle ORM migration conflict resolution |
| `config/example.env` | Template for user configuration |
| `docs/_config.yml` | Jekyll/GitHub Pages configuration |
| `docs/tasks/` | Task tracking (use `YYYY-MM-DD-description.md`) |
| `docs/prds/` | PRDs for major features (use `YYYY-MM-DD-feature.md`) |

## Architecture Notes

1. **PR Merging**: Workflow fetches PRs by number, attempts merge, uses lazy rebase on conflict
2. **Drizzle Conflicts**: Two-phase migration conflict resolution:
   - **Phase 1** (`drizzle_migration_manager.py`): Renumber conflicting files, update journal
   - **Phase 2** (`drizzle-kit up`): Regenerate snapshots using Dokploy's tooling
   - Handles both snapshot naming conventions: `{idx}_snapshot.json` and `{tag}.json`
   - Validates integrity after changes
3. **Multi-arch Builds**: Separate builds for amd64/arm64, combined with manifest
4. **Install Script**: Generates `docker-compose.yml` and `.env` at `/etc/dokploy/`

## Documentation

### docs/ Website

GitHub Pages site using Jekyll with Just the Docs theme (dark mode):

| Page | Nav Order | Purpose |
|------|-----------|---------|
| `index.md` | 1 | Homepage, value proposition, quick start |
| `why.md` | 2 | Project motivation (slow PRs, enterprise gaps) |
| `getting-started.md` | 3 | Fork, configure, run your own builds |
| `installation.md` | 4 | Detailed installation reference |
| `configuration.md` | 5 | Environment variables and settings |
| `contributing.md` | 6 | Dual paths: Dokploy PRs + this project |
| `migration.md` | 7 | Migrate from official Dokploy |
| `troubleshooting.md` | 8 | Common issues and solutions |

### Documentation Rules

- Pages require front matter: `layout`, `title`, `nav_order`, `permalink`
- Use theme callouts: `{: .warning }`, `{: .note }`, `{: .highlight }`
- Tasks and PRDs use date-prefixed naming: `YYYY-MM-DD-description.md`
- Follow templates in `docs/tasks/README.md` and `docs/prds/README.md`
- Create a PRD before implementing major features
- Update website pages when user-facing features change
- Tasks and PRDs are excluded from GitHub Pages build
