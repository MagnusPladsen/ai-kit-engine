---
description: Testing standards and best practices
globs: "**/*.{test,spec}.{ts,tsx,js,jsx,cs,py,go}"
alwaysApply: false
---

# Testing Conventions

- Descriptive test names: `should [action] when [condition]`
- One assertion per test — test one behavior at a time
- Mock external dependencies (APIs, databases, file system) — never call real services in unit tests
- Cover edge cases: empty input, null, boundary values, error paths
- Never skip tests without a linked ticket explaining why
- Run tests before considering work done
- Tests are documentation — a new developer should understand the feature by reading the tests
