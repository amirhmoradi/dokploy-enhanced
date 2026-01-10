# CLAUDE.md

> Project context for Claude Code. See [Anthropic's best practices](https://www.anthropic.com/engineering/claude-code-best-practices).

## Project Overview

Dokploy Enhanced is an automated distribution of [Dokploy](https://github.com/Dokploy/dokploy) that:
- Syncs daily with upstream Dokploy (canary branch)
- Merges selected community PRs automatically
- Builds multi-arch Docker images (amd64 + arm64)
- Publishes to `ghcr.io/amirhmoradi/dokploy-enhanced`

## Repository Structure

```
├── install.sh                           # Main installation script (bash)
├── .github/
│   ├── workflows/auto-merge-build.yml   # CI/CD workflow (GitHub Actions)
│   └── scripts/                         # Python scripts for Drizzle migrations
│       └── drizzle_migration_manager.py # Comprehensive migration conflict resolver
├── config/example.env                   # Example environment configuration
├── docs/                                # Documentation (GitHub Pages site)
│   ├── _config.yml                      # Jekyll configuration (Just the Docs theme)
│   ├── index.md                         # Homepage with value proposition
│   ├── why.md                           # Project motivation and philosophy
│   ├── getting-started.md               # Fork, configure, run guide
│   ├── installation.md                  # Installation reference
│   ├── configuration.md                 # Configuration reference
│   ├── contributing.md                  # Contribution guide (dual paths)
│   ├── migration.md                     # Migration from official Dokploy
│   ├── troubleshooting.md               # Troubleshooting guide
│   ├── assets/                          # Static assets (images, CSS)
│   ├── _sass/custom/                    # Custom SCSS styles
│   ├── tasks/                           # Task management documents
│   └── prds/                            # Product Requirements Documents
├── README.md                            # User documentation
└── CONTRIBUTING.md                      # Contribution guidelines
```

## Commands

```bash
# Test install script in dry-run mode
DRY_RUN=true bash install.sh

# Test GitHub Actions locally (requires 'act')
act -W .github/workflows/auto-merge-build.yml

# Lint shell scripts
shellcheck install.sh

# Run Drizzle migration manager
python3 .github/scripts/drizzle_migration_manager.py <drizzle_dir> --mode fix --verbose
python3 .github/scripts/drizzle_migration_manager.py <drizzle_dir> --mode validate
python3 .github/scripts/drizzle_migration_manager.py <drizzle_dir> --mode cleanup
```

## Code Style

### Shell Scripts (install.sh)
- Shebang: `#!/usr/bin/env bash`
- Strict mode: `set -euo pipefail`
- Use uppercase for constants: `DOKPLOY_VERSION`, `DATA_DIR`
- Use lowercase for local variables: `local result`, `local port`
- Functions use snake_case: `check_requirements()`, `generate_compose_file()`
- All functions should have a single responsibility
- Add comments for complex logic
- Follow ShellCheck recommendations

### Python Scripts (.github/scripts/)
- Python 3.x compatible
- Use argparse for CLI arguments
- Include docstrings for functions
- Handle edge cases gracefully

### YAML (workflows, docker-compose)
- 2-space indentation
- Quote strings that could be misinterpreted
- Add comments for non-obvious configurations

## Workflow Context

The GitHub Actions workflow (`auto-merge-build.yml`):
1. Clones upstream Dokploy from canary branch
2. Fetches and merges PRs listed in `PR_NUMBERS_TO_MERGE` variable
3. Handles Drizzle ORM migration conflicts via Python scripts
4. Pins pnpm to v9.x for compatibility
5. Builds Docker images for both amd64 and arm64
6. Pushes to GitHub Container Registry with date-based tags

## Key Technical Details

- **Drizzle migrations**: When merging PRs with database migrations, a multi-phase approach handles conflicts:
  - **Phase 1 - Conflict Resolution** (workflow):
    - Extracts PR's snapshot to temp before resolving conflict (preserves both versions)
    - Keeps base's snapshot at original index, creates PR's at new index
    - Merges journals and renumbers PR migrations to next available index
  - **Phase 2 - File Renaming** (`drizzle_migration_manager.py`):
    - Renames SQL files with new index
    - Creates new snapshot from extracted PR version
    - Handles both naming conventions: `{idx}_snapshot.json` and `{tag}.json`
  - **Phase 3 - Validation** (drizzle-kit):
    - Runs `drizzle-kit up` to update migration metadata format
    - Uses Dokploy's tooling to ensure snapshots are valid
- **Docker Swarm**: install.sh initializes Docker Swarm for overlay networking
- **Traefik**: Optional reverse proxy with Let's Encrypt SSL
- **PostgreSQL 16 + Valkey (Redis)**: Data persistence layer

## Git Workflow

- Branch from `main`
- Use conventional commits: `feat:`, `fix:`, `docs:`, `chore:`
- PRs should reference related issues
- Include `Co-Authored-By: Claude <noreply@anthropic.com>` in AI-assisted commits

## Testing Changes

Before submitting PRs:
1. Run `shellcheck install.sh` for shell script linting
2. Test with `DRY_RUN=true bash install.sh`
3. Verify YAML syntax in workflow files
4. Test Python scripts with sample migration journals

## Documentation

### docs/ Website Structure

The `docs/` folder is a GitHub Pages site using Jekyll with the Just the Docs theme:

| Page | Purpose |
|------|---------|
| `index.md` | Homepage with value proposition and quick start |
| `why.md` | Project motivation (slow PRs, enterprise gaps) |
| `getting-started.md` | Fork, configure, and run your own builds |
| `installation.md` | Detailed installation reference |
| `configuration.md` | Environment variables and settings |
| `contributing.md` | Dual contribution paths (Dokploy + this project) |
| `migration.md` | Migrate from official Dokploy |
| `troubleshooting.md` | Common issues and solutions |

### Internal Documentation

- **tasks/** - Task tracking documents (naming: `YYYY-MM-DD-description.md`)
- **prds/** - Product Requirements Documents for major features
- These folders are excluded from GitHub Pages build

### Documentation Rules

- Website pages use Jekyll with Just the Docs theme (dark mode)
- Pages require front matter: `layout`, `title`, `nav_order`, `permalink`
- Use theme callouts: `{: .warning }`, `{: .note }`, `{: .highlight }`
- Follow templates in `docs/tasks/README.md` and `docs/prds/README.md`
- Create a PRD before implementing major features
- Update website pages when user-facing features change

## Documentation Maintenance

**Important**: When making any changes to the project, you must update:

- `CLAUDE.md` - Update if adding new files, commands, conventions, or technical details
- `AGENTS.md` - Update if adding new files, commands, structure, boundaries, or workflows
- `docs/` - Update relevant documentation pages when features change

These files serve as the source of truth for AI coding agents working on this project. Keeping them current ensures consistent and accurate assistance.
