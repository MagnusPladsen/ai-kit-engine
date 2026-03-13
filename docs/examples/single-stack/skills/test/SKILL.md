# /test — Run and Analyze Tests

Run Go tests with coverage and analyze the results.

## Steps

1. **Identify scope** — ask the user: specific package, changed packages, or all?
2. **Run tests:**
   - Specific: `go test -v -race -count=1 ./path/to/package/...`
   - Changed: detect changed `.go` files via `git diff --name-only`, extract unique packages, test those
   - All: `go test -v -race -count=1 -coverprofile=coverage.out ./...`
3. **Analyze results:**
   - If all pass, report summary (packages tested, time elapsed)
   - If any fail, show the failing test name, the assertion that failed, and suggest a fix
4. **Coverage report** (when running all):
   - Run `go tool cover -func=coverage.out`
   - Highlight any packages below 70% coverage
   - Suggest specific functions that need tests
5. **Clean up** — remove `coverage.out` after reporting

## Important

- Always use `-race` to detect data races
- Use `-count=1` to disable test caching
- If tests require a database or external service, warn the user before running
