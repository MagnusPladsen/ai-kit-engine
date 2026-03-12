---
description: Security basics — no secrets in code, input sanitization, auth patterns
alwaysApply: true
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Security

- Never commit secrets, API keys, tokens, or credentials — use environment variables or secret managers
- No hardcoded passwords, connection strings, or auth tokens in source
- Validate and sanitize all user input at system boundaries
- Use parameterized queries — never string-concatenate SQL
- Apply principle of least privilege for API endpoints and database access
- Don't log sensitive data (passwords, tokens, PII, credit cards)
- Use HTTPS for all external API calls
- Auth tokens belong in headers, never in URLs or query strings
- Flag `.env` files, `credentials.json`, and similar in `.gitignore`
- If you spot a secret in code during any task, flag it immediately
