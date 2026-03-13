# Clean Architecture

Standard 6-project layout with strict dependency direction:

- **Domain** — zero dependencies, pure business logic (entities, value objects, domain events)
- **Application** — depends on Domain only, defines interfaces, commands, queries
- **Infrastructure** — implements Application interfaces (email, storage, external APIs)
- **Persistence** — EF Core DbContext, entity configurations, migrations
- **Api** — controllers, middleware, DI composition root
- **Common** — shared utilities referenced by all layers

Dependency direction: `Api -> Application -> Domain`, `Api -> Infrastructure -> Persistence`

Never reference a higher layer from a lower one. Domain must have zero NuGet dependencies.
Use MediatR for command/query dispatch. One handler per file, one command per file.
