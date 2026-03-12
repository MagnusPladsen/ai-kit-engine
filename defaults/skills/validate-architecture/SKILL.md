---
name: validate-architecture
description: Validate clean architecture rules (.NET only)
user_invocable: true
stack: dotnet
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# /validate-architecture

Validate the codebase against clean architecture rules. Only for .NET projects.

## Checks

1. **Dependency direction** — no cross-layer violations between projects
2. **Entity configurations** — every entity has an `IEntityTypeConfiguration`
3. **DI registration** — all repository/query interfaces are registered
4. **Command handlers** — all use the Result pattern via `ICommandHandler`
5. **Multi-tenant filtering** (if applicable) — tenant-scoped queries filter by tenant ID

## Output

Produce a pass/fail checklist:
```
✅ Dependency direction — no violations
❌ Entity configurations — MissingEntity has no configuration
✅ DI registration — all interfaces registered
```

Skip checks that don't apply to the project (e.g. skip multi-tenant check if no tenant pattern detected).
