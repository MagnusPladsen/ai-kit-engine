---
name: commit
description: Create a contextual git commit with ticket reference
user_invocable: true
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# /commit

Create a well-structured git commit message with ticket context.

## Steps

1. **Get branch name** — extract ticket key (e.g. `PROJ-123`, `AB-45`) from branch name. If no ticket key found, use a descriptive subject line instead.
2. **Fetch ticket context** (if Atlassian MCP available) — get issue title and description for context. Skip if unavailable.
3. **Stage files** — `git add` specific changed files. Never use `git add -A`.
4. **Show diff summary** — show what will be committed.
5. **Create commit message** in format:
   ```
   TICKET-XX: Short description of what changed

   - Bullet points of specific changes
   - One line per logical change

   Co-Authored-By: AI Assistant <noreply@example.com>
   ```
   If no ticket key: omit the prefix, use a descriptive subject line.
6. **Commit** — run `git commit`.
7. **Ask about push** — if the user said "commit and push", push. Otherwise ask.

## Rules

- Message subject line max 72 characters
- Use present tense ("Add feature" not "Added feature")
- Group related changes, don't list every file
