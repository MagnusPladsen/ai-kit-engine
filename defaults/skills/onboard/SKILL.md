---
name: onboard
description: Generate a project overview for new developers
---

# /onboard — Project Overview

Generate a quick-start guide for a new developer joining this project.

## Steps

1. **Detect stack and tooling:**
   - Package manager (npm, yarn, pnpm, pip, cargo, dotnet)
   - Framework (Next.js, Express, FastAPI, ASP.NET, etc.)
   - Language version and config (tsconfig, .python-version, go.mod)
   - Test framework, linter, formatter

2. **Map project structure:**
   - Key directories and their purpose
   - Entry points (main files, route definitions)
   - Config files and what they control

3. **Document key commands:**
   - How to install dependencies
   - How to run the dev server
   - How to run tests
   - How to build for production
   - How to run linting/formatting

4. **Identify patterns:**
   - Architecture pattern (MVC, Clean Architecture, feature-based)
   - State management approach
   - API integration pattern
   - Authentication/authorization approach

5. **Check for existing docs:**
   - README.md, CONTRIBUTING.md, CLAUDE.md, AGENTS.md
   - Summarize what's already documented vs what's missing

6. **Output** a concise overview covering all the above — formatted for quick scanning

## Important

- Focus on what a new developer needs to be productive in their first hour
- Don't explain basic language features — assume the developer knows the language
- Highlight any non-obvious conventions or gotchas
