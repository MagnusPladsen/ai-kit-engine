---
description: Repository (write) vs query (read) split
globs: "**/*.cs"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Repository & Query Pattern

- **Repositories** handle writes, accept/return domain models, registered `AddScoped`
- **Queries** handle reads, return DTOs, registered `AddTransient`, use `AsNoTracking()`
- Interfaces in Application, implementations in Infrastructure
- Mapping methods are `private static` — no AutoMapper
- Never map DTO→domain or DTO→entity
- Filter by `OrganizationId` in all multi-tenant queries
