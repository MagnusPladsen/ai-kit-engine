---
description: Database conventions — naming, migrations, indexes, safety
globs: "**/*.{cs,sql}"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Database

- Table names: PascalCase, plural (e.g. `CarrierRoutes`, `ShipmentAssignments`)
- Column names: PascalCase (e.g. `Title`, `OrganizationId`, `StartDateTime`)
- Foreign keys: `{EntityName}Id` (e.g. `CarrierRouteId`)
- Primary keys: always `Id` (Guid or int)
- Indexes: auto-generated EF format `IX_TableName_ColumnName`. Add explicit indexes on FK columns and frequently queried combinations
- Unique indexes: explicit with `IsUnique()` for natural keys (e.g. `Code`)
- String properties: always set explicit `HasMaxLength()` constraints
- Enums: store as strings with `HasConversion<string>()` and `HasMaxLength()`
- Soft delete: set `DeletedAt`/`DeletedBy` — never use `context.Remove()`. Use global query filters for soft-delete
- Timestamps: `DateTimeOffset` for all timestamps, `DateOnly`/`TimeOnly` for date/time-only values
- Delete behavior: `Restrict` for tenant/org relationships, `Cascade` only for owned children
- Migrations: descriptive PascalCase names, review `Up()`/`Down()` before committing, never modify migrations already on shared environments
- All audit fields (`CreatedBy`/`At`, `LastModifiedBy`/`At`) populated automatically via `SaveChangesAsync` override
