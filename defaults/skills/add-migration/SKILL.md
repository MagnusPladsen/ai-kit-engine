---
name: add-migration
description: EF Core migration workflow (.NET only)
user_invocable: true
stack: dotnet
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# /add-migration

Guided EF Core migration creation. Only for .NET projects.

## Steps

1. **Detect changes** — check for entity/configuration changes since last migration
2. **Build solution** — `dotnet build` must succeed before creating migration
3. **Suggest name** — PascalCase descriptive name based on changes (e.g. `AddMaxWeightToCarrierRoute`)
4. **Find projects** — look for `*.csproj` files matching Persistence/Data and Api/Web patterns in the solution. Ask the user if ambiguous.
5. **Create migration:**
   ```bash
   dotnet ef migrations add <Name> --project <PersistenceProject> --startup-project <ApiProject>
   ```
6. **Review** — show generated `Up()` and `Down()` methods for user review
7. **Optionally apply** — offer to run `dotnet ef database update` locally
8. **Summary** — list created files and current migration count

## Rules

- Never modify an already-applied migration
- Commit entity changes and migration together
- Never run `database update` against production
