---
description: Clean architecture layer boundaries
globs: "**/*.cs"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Clean Architecture

Standard 6-project layout with strict dependency direction:

- **Domain** — zero dependencies, pure business logic
- **Application** — depends on Domain only, defines interfaces
- **Infrastructure** — implements Application interfaces
- **Persistence** — EF Core, entities, configurations
- **Api** — controllers, middleware, DI composition root
- **Common** — shared utilities, referenced by all

Dependency direction: `Api → Application → Domain`, `Api → Infrastructure → Persistence`

Never reference a higher layer from a lower one.
