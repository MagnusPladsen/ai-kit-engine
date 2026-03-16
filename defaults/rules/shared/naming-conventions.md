---
description: Consistent naming across the codebase
globs: "**/*"
alwaysApply: true
---

# Naming Conventions

- Directories and files: kebab-case (except components which use PascalCase)
- Variables and functions: camelCase (or snake_case per language convention)
- Constants: SCREAMING_SNAKE_CASE
- Booleans: start with is/has/should/can/will (`isLoading`, `hasError`, `canSubmit`)
- Functions: start with a verb (`getUser`, `handleClick`, `validateInput`)
- Avoid abbreviations — `response` not `res`, `request` not `req`, `error` not `err`
- Match existing patterns in the codebase — consistency beats personal preference
