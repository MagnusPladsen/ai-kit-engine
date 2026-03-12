# AI Kit Engine

Generic TUI installer engine for AI-assisted development kits. Create your own branded AI kit by editing one config file.

## What is this?

This is the **engine**, not a kit. It provides the interactive installer, theme system, profile presets, stack detection, and file management -- but ships no branding or opinionated content.

Content repos consume this engine as a git submodule. One company is already using this in production. They provide a `kit.toml` for branding, plus their own rules, skills, profiles, and registry. The engine reads `kit.toml` at runtime and adapts everything -- menus, file paths, watermarks, themes -- to your brand.

## Getting Started

### Option A (recommended): npx scaffolder

```bash
npx ai-kit-engine init
```

Asks a few questions, generates everything.

### Option B: curl bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/MagnusPladsen/ai-kit-engine/main/bootstrap.sh | bash
```

Same scaffolding, no Node.js needed.

### Option C: Template repo

Clone [ai-kit-engine-template](https://github.com/MagnusPladsen/ai-kit-engine-template) and edit to taste.

> All three methods produce the same result: a content repo with `kit.toml`, wrapper `install.sh`, and the engine as a git submodule.

Then run:

```bash
bash install.sh
```

## Features

- **Interactive TUI** -- color themes, animated menus, checkbox selection, fuzzy search, keyboard navigation
- **10 built-in themes + custom themes** -- switch live with `t`, define your own in `kit.toml`
- **Profile presets** -- one-click configurations that pre-select rules, skills, and plugins
- **Stack detection** -- auto-detects React, .NET, Python, etc. from project files
- **Team config sharing** -- export selections to a config file teammates can import
- **Fuzzy search** -- press `/` in any menu to filter items
- **Token budget estimates** -- color-coded token counts for every rule and skill
- **File safety** -- backups before overwrites, watermark tracking, clean uninstall with restore
- **Multi-tool support** -- one install configures Claude, Gemini, Codex, Windsurf, Continue.dev, Copilot, and Cursor
- **Global + project install modes** -- project mode for repos, global mode for symlinked central config
- **Manage mode** -- re-run to add, remove, or update individual items
- **Dry run mode** -- preview changes before writing anything

## `kit.toml` quick reference

```toml
[branding]
name = "My AI Kit"           # Full display name
short_name = "MY-KIT"        # Uppercase short name
tagline = "..."              # One-liner below the logo
watermark = "my-ai-kit"      # File markers and backup suffixes
config_dir = ".my-kit"       # Installed config directory name
ascii_art_file = "branding/ascii.txt"  # Optional logo

[settings]
default_theme = "Tokyo Night" # Initial theme

[defaults]                    # Toggle engine defaults (all true by default)
rules = true
skills = true
registry = true
profiles = true

[[custom_themes]]             # Define custom color themes
name = "My Brand"
lime = [200, 214, 75]         # Primary accent
teal = [62, 205, 198]         # Secondary accent
gold = [220, 200, 60]         # Mid-tone accent

[stacks.react]                # Technology stack definitions
name = "React / Next.js"
detect = ["package.json"]     # Auto-detection file patterns
rules_dir = "react"           # Subdirectory under rules/

[wrapper_files]               # AI tool instruction files
items = ["CLAUDE.md", "COPILOT.md", "CURSOR.md", "CODEX.md", "GEMINI.md"]

[global_symlinks.claude]      # Symlink targets for global installs
name = "Claude Code"
cli = "claude"
paths = [
    { src = "CLAUDE.md", dst = "~/.claude/CLAUDE.md" },
    { src = ".claude/rules/", dst = "~/.claude/rules/" },
]
```

See [docs/REFERENCE.md](docs/REFERENCE.md) for the full field reference, example configs, and defaults system details.

## Content repo structure

```
your-ai-kit/
├── kit.toml                # Branding, stacks, themes, settings
├── install.sh              # Thin wrapper (~15 lines)
├── branding/
│   └── ascii.txt           # ASCII art logo (optional)
├── rules/
│   ├── shared/             # Rules installed for all stacks
│   ├── react/              # Stack-specific rules
│   └── dotnet/
├── skills/
│   ├── commit/
│   │   └── SKILL.md
│   └── create-pr/
│       └── SKILL.md
├── profiles/
│   ├── minimal.toml
│   └── full-stack.toml
├── registry.toml           # Plugin & MCP server metadata
├── CLAUDE.md               # AI tool instruction files
├── COPILOT.md
├── CURSOR.md
├── CODEX.md
├── GEMINI.md
├── AGENT.md
└── engine/                 # AI Kit Engine (git submodule)
```

## Adding content

| Want to add... | How |
|----------------|-----|
| A rule | Create `rules/{category}/{name}.md` |
| A skill | Create `skills/{name}/SKILL.md` |
| A plugin | Add `[plugins.name]` to `registry.toml` |
| An MCP server | Add `[mcps.name]` to `registry.toml` |
| A profile | Create `profiles/{name}.toml` |
| A custom theme | Add `[[custom_themes]]` to `kit.toml` |
| A stack | Add `[stacks.key]` to `kit.toml` |

### Profile format

```toml
name = "My Profile"
description = "What this profile includes"
stacks = ["react", "integrations"]

[rules]
items = ["commit-conventions", "security", "typescript"]

[skills]
items = ["commit", "create-pr", "review"]

[plugins]
items = ["superpowers", "coderabbit"]
```

### Registry format

```toml
[plugins.my-plugin]
tokens = 500
heavy = true              # Optional: shown in yellow
stack = "react"           # Optional: only shown for this stack

[mcps.my-server]
url = "https://example.com/mcp"

[mcps.context7]
url = "npx:-y:@upstash/context7-mcp"   # npx with colon-separated args
```

## CLI flags

| Flag | Description |
|------|-------------|
| `--help`, `-h` | Show usage information |
| `--check` | Verify installed files are in sync with kit source |
| `--update` | Re-install, overwriting with latest |
| `--uninstall` | Remove kit files and restore backups |
| `--list` | Show installed rules, skills, and plugins |
| `--dry-run` | Preview without writing files |

```bash
bash install.sh --check
bash install.sh --dry-run
bash install.sh --uninstall
```

## Contributing

### Ground rules

- **Never hardcode brand names** -- all branding comes from `kit.toml`
- **Never break backward compatibility** -- existing `kit.toml` files must keep working
- **Every commit bumps `VERSION`** -- see `.claude/rules/versioning.md`
- **New `kit.toml` fields must have defaults** -- the engine must work with a minimal config
- **Default content must be universally applicable** -- no brand-specific references

### Testing changes

```bash
cd ../my-ai-kit
bash install.sh --dry-run
bash install.sh
bash install.sh --check
bash install.sh --uninstall
```

## License

MIT
