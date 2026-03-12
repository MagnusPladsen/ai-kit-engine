---
description: CQRS pattern with MediatR
globs: "**/*.cs"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# CQRS with MediatR

- **Writes** go through MediatR commands; **reads** use query interfaces directly
- Commands are records with `required init` properties
- Handlers return `Result<T>` — never throw for business rule violations
- One command per file, one handler per file
- Naming: `Create{Feature}Command.cs` + `Create{Feature}CommandHandler.cs`
- No direct DbContext injection in handlers — use repositories
