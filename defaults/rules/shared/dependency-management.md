---
description: Be intentional about adding dependencies
globs: "{package.json,requirements.txt,pyproject.toml,go.mod,*.csproj,Cargo.toml,Gemfile}"
alwaysApply: false
---

# Dependency Management

- Justify every new dependency — it adds attack surface and maintenance burden
- Prefer stdlib or built-in features for simple tasks
- Pin versions to avoid surprise breaking changes
- Check license compatibility before adding
- One library per concern — don't add two packages that do the same thing
- If a dependency is only used in one place, consider inlining the logic
