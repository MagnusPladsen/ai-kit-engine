---
description: Never auto-push — only push when explicitly requested
alwaysApply: true
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# No Auto-Push

Never run `git push` unless the user explicitly asks to push. This includes:
- After committing — always ask first
- After creating branches
- After any git operation that could send data to remote

Committing locally is fine. Pushing requires explicit permission every time.
