---
description: Error handling with Result pattern
globs: "**/*.cs"
alwaysApply: false
---

<!-- abaris-ai-kit | Do not edit - managed by install.sh | Run install.sh --check to verify -->

# Error Handling (Backend)

- Use `Result<T>` for expected failures — never throw for business rules
- Error naming: `Error("Domain.ErrorType", "message")`
- Controllers map errors: "NotFound" in name → 404, others → 400
- Check `result.IsFailure` before accessing `result.Value`
- Let `GlobalExceptionFilter` handle truly unexpected exceptions
- `GlobalExceptionFilter` maps to ProblemDetails (RFC 7807)
