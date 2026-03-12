---
description: Jira integration - triggers when working with tickets, branches, commits, or PRs
globs: "**/*"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Jira Integration

## Setup

Requires the Atlassian MCP server:
```bash
claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse
```

## Usage in skills

The `/commit`, `/create-pr`, and `/new-issue` skills automatically use Jira when available:

1. **Extract ticket key** from branch name (e.g., `PROJ-123` from `feature/PROJ-123-add-login`)
2. **Fetch issue** via `mcp__atlassian__getJiraIssue` with the project's cloudId
3. **Use context** for commit messages, PR descriptions, and planning

## Finding your cloudId

Use the Atlassian MCP tool:
```
Tool: mcp__atlassian__getAccessibleAtlassianResources
```
This returns your available Jira/Confluence sites with their cloudId values.

## Graceful degradation

All skills work without Jira — they just won't have ticket context. Never block a workflow because Jira is unavailable.

## Linking back

When creating PRs, add a comment to the Jira issue with the PR link:
```
Tool: mcp__atlassian__addCommentToJiraIssue
Parameters:
  - cloudId: "<your-cloud-id>"
  - issueIdOrKey: "PROJ-123"
  - commentBody: "PR created: <PR_URL>"
```
