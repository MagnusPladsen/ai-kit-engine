---
description: Visual consistency — spacing, typography, colors, radii, icons
globs: "**/*.{tsx,jsx,vue,svelte,css,scss,html}"
alwaysApply: false
---

# Design Consistency

- **Colors:** Never hardcode hex/rgb values — use theme tokens (Tailwind classes, CSS variables, or design system tokens). For raw color props (icon `color`, `tintColor`), import from a centralized colors config derived from your theme
- **Border radius:** Use consistent radius tokens (e.g. `rounded-md`). Small elements (badges, chips) need slightly more radius to appear visually consistent with larger elements
- **Typography:** Use a defined scale for headings (h1-h6), body, and caption text. Don't mix font sizes ad-hoc — stick to the scale
- **Font weight:** Use consistent weight conventions — bold for headings and emphasis, medium for labels, regular for body. Don't mix arbitrarily
- **Spacing:** Use a spacing scale (4px/8px/12px/16px/24px/32px). Don't use magic numbers for margins and padding
- **Icons:** Use one icon library consistently. Don't mix icon sets (e.g. Lucide + FontAwesome). Match icon size to text size
- **Shadows:** Use defined shadow tokens (sm/md/lg). Don't create one-off box-shadows
- **Transitions:** Use consistent duration and easing. Prefer 150-200ms for micro-interactions, 300ms for layout changes
- **States:** Every interactive element needs hover, focus, active, and disabled states. Style them consistently across the app
- **Empty states:** Every list, table, or data view needs an empty state — never show a blank area
