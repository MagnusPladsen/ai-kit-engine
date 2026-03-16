---
name: test
description: Write and run tests for specified code
---

# /test — Write and Run Tests

Write tests for specified code, run them, and iterate until passing.

## Steps

1. **Detect test framework** — check project config for the test runner:
   - `package.json` → Jest, Vitest, or Mocha
   - `pyproject.toml` / `pytest.ini` → pytest
   - `go.mod` → `go test`
   - `*.csproj` → xUnit, NUnit, or MSTest
   - Ask if ambiguous

2. **Identify what to test** — ask the user if not specified:
   - A specific function, class, or module
   - Changed files (via `git diff --name-only`)
   - A specific behavior or edge case

3. **Write the tests:**
   - Follow existing test patterns in the project (naming, structure, helpers)
   - Descriptive names: `should [action] when [condition]`
   - One assertion per test
   - Cover: happy path, edge cases (null, empty, boundary), error paths
   - Mock external dependencies (APIs, databases, file system)

4. **Run the tests:**
   - Use the project's test command (`npm test`, `pytest`, `go test`, `dotnet test`)
   - Show full output on failure

5. **Iterate:**
   - If tests fail, analyze the failure and fix
   - If the implementation has a bug (test is correct but code is wrong), ask the user before fixing the implementation

## Important

- Follow existing test conventions in the project — don't introduce a new style
- Place test files according to project convention (co-located, `__tests__/`, or `tests/`)
- Never modify the implementation to make a test pass without user approval
