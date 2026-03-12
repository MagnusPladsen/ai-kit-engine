---
description: API integration patterns
globs: "**/*.{ts,tsx}"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# API Integration

- All API calls go through a centralized client (e.g. `lib/api/`), not ad-hoc fetches
- Verify endpoint contracts from Swagger/OpenAPI or backend source before implementing
- Don't duplicate endpoint URLs — single source of truth
- Handle network, validation, auth, and unknown errors explicitly
- Show localized user-safe error messages
- Rollback optimistic state on failure
