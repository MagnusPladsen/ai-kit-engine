---
description: Domain model design rules
globs: "**/Domain/**/*.cs"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Domain Models

- Pure records with static `Create` factory methods and invariant validation
- Collections exposed as `IReadOnlyList<T>`, mutated via named methods
- Value objects are positional records
- No EF Core or persistence dependencies
- Prefer computed properties for derived state
- Avoid anemic models and mutable public setters
