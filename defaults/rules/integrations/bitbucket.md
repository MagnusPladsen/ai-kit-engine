---
description: Bitbucket conventions - triggers when working with Bitbucket repos
globs: "**/*"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Bitbucket Conventions

Abaris primarily uses Bitbucket for source control.

## Detecting Bitbucket

```bash
git remote get-url origin | grep -q 'bitbucket.org'
```

## Pull Requests

Bitbucket has no official CLI. For PR creation:

1. **Push branch** to remote
2. **Generate PR URL** and open in browser:
   ```bash
   # Extract org/repo from remote
   REMOTE=$(git remote get-url origin)
   ORG=$(echo "$REMOTE" | sed 's|.*bitbucket.org[:/]\(.*\)/.*|\1|')
   REPO=$(echo "$REMOTE" | sed 's|.*/\(.*\)\.git|\1|')
   BRANCH=$(git branch --show-current)

   # Open PR creation page
   open "https://bitbucket.org/${ORG}/${REPO}/pull-requests/new?source=${BRANCH}"
   ```

3. **Or use Bitbucket REST API** if authentication is configured:
   ```bash
   curl -X POST \
     -u "user:app-password" \
     "https://api.bitbucket.org/2.0/repositories/ORG/REPO/pullrequests" \
     -H "Content-Type: application/json" \
     -d '{"title": "TICKET-XX: Title", "source": {"branch": {"name": "BRANCH"}}, "destination": {"branch": {"name": "main"}}}'
   ```

## Branch naming

- Feature: `feature/TICKET-XXX-short-description`
- Bugfix: `bugfix/TICKET-XXX-short-description`
- Hotfix: `hotfix/TICKET-XXX-short-description`

## Conventions

- Default branch is usually `main`
- PRs require at least one reviewer before merge
- Squash merge is preferred for clean history
