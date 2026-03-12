---
description: Azure DevOps conventions - triggers when using az CLI or working with Azure DevOps repos
globs: "**/*"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Azure DevOps Conventions

## CLI tool

Use the `az` CLI for Azure DevOps operations. Never use `gh` (GitHub CLI) on Azure DevOps repos.

## Detecting Azure DevOps

```bash
git remote get-url origin | grep -q 'dev.azure.com\|visualstudio.com'
```

## Common commands

### Pull Requests

```bash
# Create PR
az repos pr create \
  --organization https://dev.azure.com/ORG \
  --project PROJECT \
  --repository REPO \
  --source-branch BRANCH \
  --target-branch main \
  --title "TICKET-XX: Title" \
  --description "Description"

# List PRs
az repos pr list --organization URL --project PROJECT --repository REPO --status active

# Check for existing PR on branch
az repos pr list --source-branch BRANCH --status active

# Update PR
az repos pr update --id PR_ID --description "Updated description"
```

### Work items

```bash
# Link work item to PR (if using Azure Boards)
az repos pr update --id PR_ID --work-items WORK_ITEM_ID
```

## PR conventions

- Title format: `TICKET-XX: Short description`
- Always check for existing PR before creating a new one
- Set target branch to the repository default (usually `main`)

## Prerequisites

```bash
# Install Azure CLI + DevOps extension
az extension add --name azure-devops
az login
az devops configure --defaults organization=https://dev.azure.com/ORG project=PROJECT
```
