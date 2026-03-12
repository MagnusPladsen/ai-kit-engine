---
name: debug
description: Structured debugging — reproduce, isolate, fix, verify
user_invocable: true
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# /debug

Systematic debugging workflow: reproduce, isolate, fix, verify.

## Steps

1. **Understand the bug** — Ask the user to describe:
   - What's happening vs what should happen
   - Steps to reproduce
   - When it started (recent change? always broken?)
   - Error messages, logs, or screenshots

2. **Reproduce** — Attempt to reproduce the issue:
   - Run the failing test or scenario
   - Check logs for error details
   - If can't reproduce, gather more context (environment, data, timing)

3. **Isolate** — Narrow down the cause:
   - Check recent git changes: `git log --oneline -20` and `git diff HEAD~5`
   - Trace the code path from entry point to failure
   - Identify the exact line/condition that causes the bug
   - Check if it's a data issue, logic error, race condition, or environment problem

4. **Hypothesize** — Form a hypothesis and verify:
   - State the suspected root cause clearly
   - Add targeted logging or breakpoints to confirm
   - Rule out alternative causes

5. **Fix** — Apply the minimal fix:
   - Change only what's needed to fix the bug
   - Don't refactor surrounding code
   - Add a regression test that fails without the fix and passes with it

6. **Verify** — Confirm the fix:
   - Run the reproduction steps — bug should be gone
   - Run the full test suite — no regressions
   - Check edge cases related to the fix

7. **Report** — Summarize:
   - Root cause (one sentence)
   - What was changed and why
   - Regression test added
   - Any follow-up work needed

## Rules

- Never guess-and-fix — always reproduce first
- Minimal fixes only — resist the urge to refactor while debugging
- Always add a regression test
- If the bug is in a dependency, document the workaround and file an upstream issue
- Check git blame if the bug seems recent — understanding why code changed helps
