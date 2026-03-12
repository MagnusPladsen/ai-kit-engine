---
description: GitHub conventions - triggers when using gh CLI or working with GitHub repos
globs: "**/*"
alwaysApply: false
---

<!-- ai-kit-engine | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# GitHub Conventions

## CLI tool

Use the `gh` CLI for GitHub operations. Never use `az` (Azure CLI) or Bitbucket APIs on GitHub repos.

## Detecting GitHub

```bash
git remote get-url origin | grep -q 'github.com'
```

## Common commands

### Pull Requests

```bash
# Create PR (interactive)
gh pr create

# Create PR (non-interactive)
gh pr create \
  --title "TICKET-XX: Title" \
  --body "Description" \
  --base main \
  --head BRANCH

# List open PRs
gh pr list --state open

# Check for existing PR on current branch
gh pr view

# Update PR description
gh pr edit PR_NUMBER --body "Updated description"

# Merge PR
gh pr merge PR_NUMBER --squash
```

### Issues

```bash
# View issue
gh issue view ISSUE_NUMBER

# List issues
gh issue list --state open

# Link PR to issue (mention in PR body)
# Use "Closes #ISSUE_NUMBER" or "Fixes #ISSUE_NUMBER" in PR description
```

### Checks & Reviews

```bash
# View CI status
gh pr checks PR_NUMBER

# Request a reviewer
gh pr edit PR_NUMBER --add-reviewer USERNAME

# View PR reviews
gh pr view PR_NUMBER --json reviews
```

## PR conventions

- Title format: `TICKET-XX: Short description`
- Always check for existing PR before creating a new one (`gh pr view`)
- Set target branch to the repository default (usually `main`)
- Use `Closes #ISSUE_NUMBER` in PR body to auto-close linked issues on merge
- Squash merge is preferred for clean history

## Branch naming

- Feature: `feature/TICKET-XXX-short-description`
- Bugfix: `bugfix/TICKET-XXX-short-description`
- Hotfix: `hotfix/TICKET-XXX-short-description`

## Prerequisites

```bash
# Install GitHub CLI
brew install gh

# Authenticate
gh auth login
```
