# AI Kit Engine

Generic TUI installer engine for AI-assisted development kits.

## What This Repo Is

This is the **engine** — a reusable, brand-agnostic installer that content repos consume as a git submodule. It reads `kit.toml` from the content repo for all branding, stacks, themes, and configuration.

## Key Constraints

- **Never hardcode brand names** — all branding comes from `kit.toml`
- **Never break backward compatibility** — see `.claude/rules/no-breaking-changes.md`
- **Every commit bumps VERSION** — see `.claude/rules/versioning.md`
- **Never auto-push** — see `.claude/rules/no-auto-push.md`

## Architecture

```
content-repo/           # e.g. abaris-ai-kit, acme-ai-kit
├── kit.toml            # Branding, stacks, themes, settings
├── install.sh          # Thin wrapper (~15 lines) that execs engine
├── rules/              # Content-specific rules
├── skills/             # Content-specific skills
├── registry.toml       # Plugin/MCP metadata
├── profiles/           # Profile presets (TOML files)
└── engine/             # ← THIS REPO (git submodule)
    ├── install.sh      # The actual TUI engine
    ├── defaults/       # Generic starter rules/skills/plugins
    └── VERSION
```

## Development

- Test changes against at least one content repo before pushing
- New `kit.toml` fields MUST have sensible defaults
- The `defaults/` directory contains generic content usable by anyone
- Default rules/skills must be universally applicable

## Rules

Rules in `.claude/rules/` are loaded automatically. Key rules:
- `engine-scope.md` — Keep engine generic, no brand-specific content
- `no-breaking-changes.md` — Backward compatibility contract
- `versioning.md` — Version bump on every commit
- `no-auto-push.md` — Never push without explicit permission
