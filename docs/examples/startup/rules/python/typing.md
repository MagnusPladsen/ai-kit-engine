# Python Type Hints

- All function signatures must have type annotations for parameters and return values
- Use `from __future__ import annotations` at the top of every module
- Prefer `list[str]` over `List[str]` (Python 3.9+ built-in generics)
- Use `TypeAlias` for complex types; use `TypedDict` for dictionary shapes
- Run `mypy --strict` in CI — no `type: ignore` without a comment explaining why
- Pydantic models are the preferred way to define data shapes
