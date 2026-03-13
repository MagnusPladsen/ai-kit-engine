# Go Conventions

- Follow Effective Go and the Go Code Review Comments wiki
- Use `gofmt` / `goimports` — no debates about formatting
- Error handling: always check errors, never use `_` to discard them
- Prefer returning `error` over panicking — reserve `panic` for truly unrecoverable situations
- Package names: short, lowercase, single-word (e.g. `http`, `user`, `store`)
- Exported names must have doc comments starting with the name
- Use `context.Context` as the first parameter in functions that do I/O
- Interfaces belong in the package that uses them, not the package that implements them
- Prefer table-driven tests with `t.Run` subtests
- Use `golangci-lint` with the project `.golangci.yml` in CI
