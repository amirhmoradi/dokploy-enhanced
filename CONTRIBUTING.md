# Contributing to Dokploy Enhanced

Thank you for your interest in contributing to Dokploy Enhanced! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Suggesting PRs to Merge](#suggesting-prs-to-merge)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)

## Code of Conduct

Please be respectful and constructive in all interactions. We aim to create a welcoming environment for all contributors.

## How to Contribute

### Reporting Issues

1. Check if the issue already exists
2. Create a new issue with a clear title and description
3. Include steps to reproduce (for bugs)
4. Add relevant labels

### Suggesting Enhancements

1. Open an issue describing the enhancement
2. Explain the use case and benefits
3. Be open to discussion and feedback

### Contributing Code

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly
5. Commit with clear messages
6. Push to your fork
7. Open a Pull Request

## Suggesting PRs to Merge

One of the main features of Dokploy Enhanced is the ability to include community PRs that haven't been merged upstream yet.

### How to Suggest a PR

1. Open an issue titled "PR Suggestion: [Brief Description]"
2. Include the following information:
   - Upstream PR number and link
   - What the PR does
   - Why it should be included
   - Any known conflicts or dependencies
   - Testing status

### Criteria for Including PRs

We consider the following when deciding to include a PR:

- **Value**: Does it fix a significant bug or add useful functionality?
- **Quality**: Is the code well-written and tested?
- **Stability**: Does it introduce any breaking changes?
- **Conflicts**: Are there merge conflicts with other included PRs?
- **Maintenance**: Will it be easy to maintain across upstream updates?

## Development Setup

### Prerequisites

- Docker and Docker Compose
- Git
- Bash shell

### Local Testing

1. Clone the repository:
   ```bash
   git clone https://github.com/amirhmoradi/dokploy-enhanced.git
   cd dokploy-enhanced
   ```

2. Test the install script in dry-run mode:
   ```bash
   DRY_RUN=true bash install.sh
   ```

3. Test the GitHub Actions workflow locally using [act](https://github.com/nektos/act):
   ```bash
   act -W .github/workflows/auto-merge-build.yml
   ```

## Pull Request Process

1. **Update Documentation**: Update the README.md if needed
2. **Test Changes**: Ensure all functionality works correctly
3. **Clear Description**: Provide a clear PR description
4. **Link Issues**: Reference any related issues
5. **Review Feedback**: Address reviewer comments promptly

### PR Title Format

Use clear, descriptive titles:
- `feat: Add support for custom Docker registries`
- `fix: Resolve port conflict detection on Ubuntu 24.04`
- `docs: Update installation guide for ARM64`
- `chore: Update Traefik to v3.6.1`

## Coding Standards

### Shell Scripts

- Use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use meaningful variable names
- Add comments for complex logic
- Follow [ShellCheck](https://www.shellcheck.net/) recommendations
- Use functions for reusable code

### YAML Files

- Use 2-space indentation
- Add comments for complex configurations
- Keep lines under 120 characters

### Markdown

- Use consistent heading hierarchy
- Include code blocks with language hints
- Add alt text for images
- Keep lines reasonable length

## Questions?

If you have questions, feel free to:
- Open a discussion on GitHub
- Create an issue with the "question" label

Thank you for contributing!
