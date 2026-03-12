---
description: No hardcoded hex/rgb colors in components
globs: "**/*.{tsx,jsx}"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# No Hardcoded Colors

- Use Tailwind classes for `className` color styling
- For raw hex props (icon `color`, `tintColor`), use a centralized colors export derived from your Tailwind/theme config
- Never put hex literals directly in component code
