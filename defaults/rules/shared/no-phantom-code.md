---
description: No commented-out code, dead paths, or deprecated remnants
globs: "**/*"
alwaysApply: true
---

# No Phantom Code

- No commented-out code — if it's unused, delete it (git has history)
- No backwards-compatibility shims for removed features
- No unused variables renamed with underscore prefix to silence linters
- No "// removed X" or "// was here" historical comments
- No deprecated wrappers that just call the new function
- If something is unused, remove it completely — don't leave ghosts
