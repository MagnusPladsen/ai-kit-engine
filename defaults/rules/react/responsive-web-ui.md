---
description: Responsive layout strategy for cross-platform apps
globs: "**/*.{tsx,jsx}"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Responsive Web UI

- Build mobile-first, then add desktop breakpoints
- Use a `useIsDesktop()` hook for layout decisions — not `Platform.OS === "web"`
- Use `Platform.OS` only for true platform-specific behavior (camera, haptics, etc.)
- Prefer `flex-col` base + `md:flex-row` upgrades
- Constrain desktop width with `max-w-*` containers
