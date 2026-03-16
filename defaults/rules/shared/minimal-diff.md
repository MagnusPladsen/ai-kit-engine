---
description: Only change what was requested — no unrelated refactoring
globs: "**/*"
alwaysApply: true
---

# Minimal Diff

- Only change what was explicitly asked — don't refactor surrounding code
- A bug fix doesn't need nearby cleanup, a feature doesn't need extra configurability
- Don't add error handling for scenarios that can't happen
- Don't add comments, docstrings, or type annotations to code you didn't change
- Don't touch formatting or whitespace outside your diff
- Don't create abstractions for one-time operations — three similar lines is fine
- If you notice something worth improving, mention it — don't silently fix it
