---
name: review
description: Review current diff or PR against project conventions
user_invocable: true
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# /review

Review code changes against project rules and conventions.

## Steps

1. **Determine scope** — Check args: if a PR number is given, fetch it with `gh pr diff <number>`. Otherwise, run `git diff` for unstaged changes or `git diff --cached` for staged changes. If no changes found, check `git diff HEAD~1` for the last commit.

2. **Load project rules** — Read all rules from `.claude/rules/` that match the changed files' globs. These are the conventions to review against.

3. **Analyze changes** — Review every changed file against loaded rules. Check for:
   - Rule violations (naming, patterns, architecture)
   - Security issues (secrets, injection, auth)
   - Missing error handling or edge cases
   - Test coverage gaps
   - Code quality (duplication, complexity, dead code)

4. **Categorize findings** — Group by severity:
   - **Critical** — Bugs, security issues, data loss risks
   - **Suggestions** — Convention violations, improvements
   - **Nits** — Style, naming, minor cleanup
   - **Positive** — Good patterns worth highlighting

5. **Present review** — Format as:
   ```
   ## Review: <scope description>

   ### Critical (N)
   - file:line — description

   ### Suggestions (N)
   - file:line — description

   ### Nits (N)
   - file:line — description

   ### What's good
   - Positive observations
   ```

6. **Offer fixes** — For each Critical and Suggestion, ask if the user wants it fixed.

## Rules

- Never auto-fix without asking
- Focus on substance over style — don't nitpick formatting if a linter handles it
- If no issues found, say so clearly and highlight what's good
- Reference specific rule names when flagging violations
