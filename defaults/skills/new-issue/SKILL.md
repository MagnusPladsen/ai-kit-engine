---
name: new-issue
description: Start work on a new issue from ticket system
user_invocable: true
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# /new-issue

Start work on a new issue. Triggered by "New issue: TICKET-XXX" or `/new-issue TICKET-XXX`.

## Steps

1. **Fresh start** — treat as a new task, focus only on this issue
2. **Extract ticket key** from user input
3. **Fetch ticket details** (if Atlassian MCP available) — title, description, acceptance criteria. If unavailable, ask the user to describe the issue.
4. **Present summary** — show what the ticket is about
5. **Create/switch branch** — branch name = ticket key (e.g. `PROJ-178`)
   - Check if branch already exists before creating
   - Create from the repository's default branch if new
6. **Enter plan mode** — design implementation approach using ticket context

## Without ticket system

If no Atlassian MCP is available, ask the user to describe the issue and proceed with branch creation and planning.
