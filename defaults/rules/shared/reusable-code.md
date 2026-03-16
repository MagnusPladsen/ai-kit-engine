---
description: Prefer reuse over duplication — check for existing code first
globs: "**/*"
alwaysApply: true
---

# Reusable Code

- Before creating a new component, utility, or helper — search the codebase for existing ones
- If similar code exists in 3+ places, extract a shared abstraction
- Shared components belong in a dedicated shared/common directory — not buried in feature folders
- Don't duplicate API clients, validation logic, formatting functions, or error handlers
- When editing a component, check if it's used elsewhere — don't break other consumers
- Keep shared code generic — no feature-specific logic in shared utilities
- Document shared components with clear props/parameters so others know they exist
