---
description: C# coding style and conventions
globs: "**/*.cs"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# C# Conventions

- File-scoped namespaces, primary constructors for DI
- `required` + `init` for immutability on DTOs and commands
- `CancellationToken` on all async methods
- `DateTimeOffset` instead of `DateTime`; `IDateTimeProvider` instead of `DateTime.Now`
- Records for DTOs/commands/domain models; classes for entities/handlers/repos/controllers
- Naming: PascalCase public, `_camelCase` private fields, `{Name}Entity` suffix, `{Name}Dto` suffix
- Avoid `async void`, `Task.Run`, magic strings, `#region`
