---
description: TypeScript conventions for React/RN/Next.js projects
globs: "**/*.{ts,tsx}"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# TypeScript Conventions

- Never use `any` — use `unknown` for untrusted data, proper types for everything else
- All promises must be awaited or explicitly voided
- Use path aliases (`@/*`) when configured
- Prefer discriminated unions over optional fields for variant types
- Use explicit return types on exported functions
- Validate with `npm run type-check` and `npm run lint` before committing
