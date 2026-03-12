---
name: refactor
description: Guided refactoring with safety checks (tests before and after)
user_invocable: true
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# /refactor

Safe, structured refactoring with verification at every step.

## Steps

1. **Identify scope** — Ask the user what to refactor (or accept from args). Read the target code to understand current structure.

2. **Run tests before** — Execute the project's test suite (detect: `npm test`, `dotnet test`, `pytest`, etc.). Record the baseline result. If tests fail before refactoring, flag it and ask whether to proceed.

3. **Plan the refactoring** — Propose the changes:
   - What will change and why
   - Files affected
   - Risk assessment (low/medium/high)
   - Get user approval before proceeding

4. **Execute changes** — Apply the refactoring. Make atomic, reviewable changes. Prefer small commits over large rewrites.

5. **Run tests after** — Execute the same test suite. Compare with baseline:
   - All pass → report success
   - New failures → immediately show which tests broke and offer to revert

6. **Show summary** — Display a diff summary of what changed, test results before/after, and any follow-up suggestions.

## Rules

- Always run tests before AND after — no exceptions
- If no test suite exists, warn the user and ask for manual verification steps
- Never change behavior — refactoring means same behavior, better structure
- If the refactoring is large, break it into smaller steps and verify between each
