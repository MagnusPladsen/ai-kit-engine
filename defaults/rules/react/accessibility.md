---
description: Accessibility standards for interactive UI
globs: "**/*.{tsx,jsx}"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Accessibility

- All interactive elements need meaningful `accessibilityLabel` / `aria-label`
- Minimum touch targets: 44x44pt (iOS), 48x48dp (Android)
- WCAG AA contrast ratios for all text
- Keyboard navigable on web — visible focus indicators
- Use semantic elements (`button`, `heading`, `link`) not generic `View`/`div` with click handlers
