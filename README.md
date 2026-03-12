# AI Kit Engine

A generic TUI installer engine for AI-assisted development kits. Content repos consume this as a git submodule and provide their own branding, rules, skills, and configuration via `kit.toml`.

## For Content Repo Authors

### Quick Start

1. Create your content repo
2. Add the engine as a submodule:
   ```bash
   git submodule add https://github.com/MagnusPladsen/ai-kit-engine.git engine
   ```
3. Create a `kit.toml` with your branding and configuration
4. Create a thin `install.sh` wrapper that execs the engine
5. Add your rules, skills, profiles, and registry

### Wrapper Script

Your `install.sh` is a thin wrapper (~15 lines):

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-update engine submodule
git -C "$SCRIPT_DIR" submodule update --init --remote engine 2>/dev/null &

# Copy engine to temp to avoid race conditions
ENGINE=$(mktemp)
cp "$SCRIPT_DIR/engine/install.sh" "$ENGINE"
chmod +x "$ENGINE"
exec "$ENGINE" --kit-dir "$SCRIPT_DIR" "$@"
```

### Content Repo Structure

```
your-ai-kit/
├── kit.toml            # Branding, stacks, themes, settings
├── install.sh          # Thin wrapper (execs engine)
├── rules/              # Your rules (category/*.md)
├── skills/             # Your skills (name/SKILL.md)
├── profiles/           # Profile presets (*.toml)
├── registry.toml       # Plugin & MCP server metadata
└── engine/             # This repo (git submodule)
```

### kit.toml

```toml
[branding]
name = "My AI Kit"
ascii_art_file = "assets/logo.txt"

[settings]
config_dir = ".my-kit"
show_logo = true
include_defaults = true        # Include engine's default rules/skills

[[stacks]]
key = "react"
name = "React / Next.js"
detect = ["package.json", "tsconfig.json"]

[[stacks]]
key = "dotnet"
name = ".NET / C#"
detect = ["*.csproj", "*.sln"]

[[custom_themes]]
name = "My Brand"
primary = "#FF6B00"
secondary = "#1A1A2E"
accent = "#00D4FF"
```

## For Engine Contributors

### Rules

- **Never hardcode brand names** — all branding comes from `kit.toml`
- **Never break backward compatibility** — content repos auto-update the submodule
- **Every commit bumps VERSION**
- New `kit.toml` fields must have sensible defaults so existing content repos continue working

### Defaults

The `defaults/` directory contains generic starter content (rules, skills) that any content repo can opt into via `include_defaults = true` in `kit.toml`. Default content must be universally applicable — no brand-specific references.

## License

MIT
