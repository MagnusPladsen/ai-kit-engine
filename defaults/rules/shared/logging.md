---
description: Structured logging — levels, format, and what to log
alwaysApply: true
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Logging

- Use structured logging (key-value pairs) not string interpolation
- Log levels: Error (failures needing attention), Warning (degraded but functional), Information (business events), Debug (dev troubleshooting)
- Error: exceptions, failed external calls, data corruption. Include correlation ID, error details, context
- Warning: retries, fallbacks, slow queries, deprecation usage
- Information: request start/end, user actions, state transitions, deployments
- Debug: variable values, method entry/exit, query details — never in production
- Never log PII (emails, names, addresses), passwords, tokens, credit card numbers, or health data
- Include correlation/request IDs for traceability across services
- Log at service boundaries (API entry, external calls, queue processing)
- Don't log inside tight loops — aggregate or sample instead
