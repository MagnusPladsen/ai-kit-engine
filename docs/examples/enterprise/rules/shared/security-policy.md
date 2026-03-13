# Security Policy

- Never commit secrets, API keys, tokens, or credentials to source control
- All user input must be validated and sanitized at system boundaries
- Use parameterized queries — never concatenate user input into SQL
- Apply principle of least privilege for all API endpoints and database roles
- Authentication tokens belong in headers, never in URLs or query strings
- Log security events (failed auth, permission denied) at Warning level
- All external API calls must use HTTPS
- Dependencies must be scanned for known vulnerabilities in CI
- PII must never appear in logs, error messages, or analytics
- Report security concerns immediately — do not silently fix and move on
