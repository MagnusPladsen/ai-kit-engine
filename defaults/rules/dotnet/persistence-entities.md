---
description: EF Core entity conventions
globs: "**/Persistence/**/*.cs"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Persistence Entities

- All entities extend `Entity` base class (Id, audit fields, soft delete)
- `{Name}Entity` suffix
- Each entity has a corresponding `IEntityTypeConfiguration<T>`
- `HasMaxLength` on all strings, explicit indexes
- Collections use private backing fields with `PropertyAccessMode.Field`
- `DeleteBehavior.Restrict` for tenant relationships, `Cascade` for owned children
- No hard deletes — soft delete only
