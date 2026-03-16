---
description: Core code quality standards
globs: "**/*"
alwaysApply: true
---

# Code Quality

- Write self-documenting code — prefer clear naming over comments
- Keep functions under 30 lines; extract helpers for complex logic
- No TODO/FIXME in main branch — create tickets instead
- Delete dead code entirely — never comment it out
- Prefer composition over inheritance
- One responsibility per function, one concern per file
- Don't repeat yourself — but don't abstract prematurely either
