---
name: create-pr
description: Full PR creation workflow with quality checks
user_invocable: true
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# /create-pr

Create or update a pull request with quality checks.

## Steps

1. **Get context** — extract ticket key from branch, fetch ticket details if Atlassian MCP is available
2. **Check git state** — warn about uncommitted changes, ensure branch is pushed
3. **Run quality checks:**
   - React/TS projects: `npm run lint` and `npm run type-check`
   - .NET projects: `dotnet build`
   - Fix any auto-fixable issues
4. **Check PR size** — warn if diff exceeds ~500 changed lines
5. **Check for existing PR** — update existing PR instead of creating duplicates
6. **Create/update PR** with:
   - Title: `TICKET-XX: Description` (or descriptive title if no ticket)
   - Body: summary of changes, ticket reference if available, testing notes
7. **Post-PR** (if Atlassian MCP available) — add PR link as comment on the ticket

## Git platform detection

Detect platform from git remote URL and use the appropriate tool:
- **Azure DevOps** — `az repos pr create`
- **Bitbucket** — Bitbucket API or open browser to create PR
- **GitHub** — `gh pr create`

If the CLI tool isn't installed, open the PR creation URL in the browser as fallback.
