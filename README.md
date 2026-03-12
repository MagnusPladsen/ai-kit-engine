# AI Kit Engine

Generic TUI installer engine for AI-assisted development kits. Create your own branded AI kit by editing one config file.

## What is this?

This is the **engine**, not a kit. It provides the interactive installer, theme system, profile presets, stack detection, and file management — but ships no branding or opinionated content.

Content repos (like `acme-ai-kit` or `my-team-ai-kit`) consume this engine as a git submodule. They provide:

- **`kit.toml`** — branding, stacks, themes, and settings
- **`rules/`** — coding standards and conventions
- **`skills/`** — slash-command skill definitions
- **`profiles/`** — one-click preset configurations
- **`registry.toml`** — plugin and MCP server metadata
- **`branding/ascii.txt`** — optional ASCII art logo

The engine reads `kit.toml` at runtime and adapts everything — menu titles, file paths, watermarks, config directories, theme palette — to your brand.

## Quick start

### 1. Create your content repo

```bash
mkdir my-ai-kit && cd my-ai-kit
git init
```

### 2. Add the engine as a submodule

```bash
git submodule add https://github.com/MagnusPladsen/ai-kit-engine.git engine
```

### 3. Create `kit.toml`

```toml
[branding]
name = "My AI Kit"
short_name = "MY-KIT"
tagline = "AI rules and skills for my team"
watermark = "my-ai-kit"
config_dir = ".my-kit"
ascii_art_file = "branding/ascii.txt"

[settings]
default_theme = "Tokyo Night"

[defaults]
rules = true
skills = true
registry = true
profiles = true
```

### 4. Create the wrapper `install.sh`

```bash
#!/bin/bash
# My AI Kit — Installer
# Thin wrapper that delegates to the AI Kit Engine submodule.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE="$SCRIPT_DIR/engine/install.sh"

# Auto-init submodule if engine is missing
if [ ! -f "$ENGINE" ]; then
    echo "Fetching installer engine..."
    git -C "$SCRIPT_DIR" submodule update --init --recursive 2>/dev/null
    if [ ! -f "$ENGINE" ]; then
        echo "Error: Could not fetch engine. Run: git submodule update --init"
        exit 1
    fi
fi

# Copy engine to temp file, then update submodule in background.
# This avoids a race condition where the background git pull replaces
# engine/install.sh while bash is still reading it (bash reads lazily).
_ENGINE_TMP="$(mktemp)"
cp "$ENGINE" "$_ENGINE_TMP"
trap 'rm -f "$_ENGINE_TMP"' EXIT

# Background update — fetched for NEXT run, not this one
git -C "$SCRIPT_DIR" submodule update --remote engine 2>/dev/null &

exec bash "$_ENGINE_TMP" --kit-dir "$SCRIPT_DIR" "$@"
```

```bash
chmod +x install.sh
```

### 5. Run it

```bash
bash install.sh
```

The engine defaults give you a fully working kit out of the box. Add your own rules, skills, and profiles as you go.

## Full `kit.toml` reference

### `[branding]`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | `"AI Kit"` | Full display name shown in menus and headers |
| `short_name` | string | `"AI-KIT"` | Uppercase short name for compact display |
| `tagline` | string | `""` | One-line description shown below the logo |
| `watermark` | string | `"ai-kit"` | Used in file markers and backup suffixes (`.before-{watermark}`) |
| `config_dir` | string | `".ai-kit"` | Directory name for installed config (e.g. `.my-kit/`) |
| `ascii_art_file` | string | `""` | Path to ASCII art logo file, relative to content repo root |

### `[settings]`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `default_theme` | string | `"Tokyo Night"` | Theme selected on first run (must match a built-in or custom theme name) |

### `[defaults]`

Controls whether engine defaults are merged with your content. All default to `true`.

| Field | Type | Description |
|-------|------|-------------|
| `rules` | bool | Include rules from `engine/defaults/rules/` |
| `skills` | bool | Include skills from `engine/defaults/skills/` |
| `registry` | bool | Include plugins/MCPs from `engine/defaults/registry.toml` |
| `profiles` | bool | Include profiles from `engine/defaults/profiles/` |

### `[[custom_themes]]`

Define custom color themes. Each theme needs three RGB color arrays.

```toml
[[custom_themes]]
name = "My Brand"
lime = [200, 214, 75]    # Primary color (headings, selections, accents)
teal = [62, 205, 198]    # Secondary color (descriptions, info text)
gold = [220, 200, 60]    # Mid-tone color (highlights, warnings)
```

You can define multiple `[[custom_themes]]` blocks. Custom themes appear before built-in themes in the theme picker.

### `[stacks.KEY]`

Define technology stacks for auto-detection. The key (e.g. `react`, `dotnet`) is used internally.

```toml
[stacks.react]
name = "React / Next.js / React Native / Expo"
detect = ["package.json", "tsconfig.json"]
rules_dir = "react"
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name shown in the installer |
| `detect` | array | File glob patterns — if any match in the project root, the stack is auto-selected |
| `rules_dir` | string | Subdirectory name under `rules/` containing this stack's rules |

Stacks without `detect` (like `integrations`) are always shown but never auto-selected.

### `[wrapper_files]`

Files that the wrapper script creates in the target project (instruction files for AI tools).

```toml
[wrapper_files]
items = ["CLAUDE.md", "COPILOT.md", "CURSOR.md", "CODEX.md", "GEMINI.md"]
```

### `[global_symlinks.KEY]`

Configure symlink targets for global installs. Each key represents an AI tool.

```toml
[global_symlinks.claude]
name = "Claude Code"
cli = "claude"
paths = [
    { src = "CLAUDE.md", dst = "~/.claude/CLAUDE.md" },
    { src = ".claude/rules/", dst = "~/.claude/rules/" },
    { src = ".claude/skills/", dst = "~/.claude/skills/" },
]
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name for the tool |
| `cli` | string | CLI command to check if the tool is installed |
| `alt_cli` | string | Alternative CLI command (checked if primary is missing) |
| `paths` | array | Source/destination pairs for symlinks (`~` is expanded) |

## Wrapper `install.sh` explained

The wrapper script is intentionally minimal (~15 lines). Here is what each section does:

```bash
# Auto-init submodule if engine is missing
if [ ! -f "$ENGINE" ]; then
    git -C "$SCRIPT_DIR" submodule update --init --recursive 2>/dev/null
fi
```

On first clone, users may not have run `git submodule update`. The wrapper handles this automatically.

```bash
# Copy engine to temp file to avoid race condition
_ENGINE_TMP="$(mktemp)"
cp "$ENGINE" "$_ENGINE_TMP"
trap 'rm -f "$_ENGINE_TMP"' EXIT
```

Bash reads scripts lazily. If the background `git submodule update` replaces `engine/install.sh` mid-execution, the running script would break. Copying to a temp file prevents this.

```bash
# Background update — fetched for NEXT run, not this one
git -C "$SCRIPT_DIR" submodule update --remote engine 2>/dev/null &
```

The engine updates silently in the background. Users get the latest version on their next run without waiting.

```bash
exec bash "$_ENGINE_TMP" --kit-dir "$SCRIPT_DIR" "$@"
```

The `--kit-dir` flag tells the engine where to find `kit.toml`, rules, skills, and other content. All other flags are passed through.

## Content repo structure

```
your-ai-kit/
├── kit.toml                # Branding, stacks, themes, settings
├── install.sh              # Thin wrapper (~15 lines)
├── branding/
│   └── ascii.txt           # ASCII art logo (optional)
├── rules/
│   ├── shared/             # Rules installed for all stacks
│   │   ├── security.md
│   │   └── logging.md
│   ├── react/              # Stack-specific rules
│   │   ├── components.md
│   │   └── typescript.md
│   └── dotnet/
│       ├── csharp.md
│       └── clean-architecture.md
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
    ├── install.sh
    ├── defaults/
    └── VERSION
```

## Defaults system

The `engine/defaults/` directory contains generic, universally applicable starter content. When a content repo sets `[defaults].rules = true` (the default), the engine merges these defaults with the content repo's own rules, skills, profiles, and registry.

### What is in defaults

```
defaults/
├── kit.toml                # Reference configuration
├── registry.toml           # Default plugins (coderabbit, superpowers, etc.)
├── rules/
│   ├── shared/             # commit-conventions, security, logging, etc.
│   ├── react/              # typescript, components, accessibility, etc.
│   ├── dotnet/             # csharp, clean-architecture, cqrs-mediatr, etc.
│   └── integrations/       # bitbucket, azure-devops, github, jira
├── skills/
│   ├── commit/             # Contextual git commit
│   ├── create-pr/          # PR creation workflow
│   ├── review/             # Diff/PR review
│   ├── refactor/           # Guided refactoring
│   ├── debug/              # Structured debugging
│   ├── document/           # Documentation generation
│   ├── new-issue/          # Start work on ticket
│   ├── add-migration/      # EF Core migrations (.NET)
│   └── validate-architecture/  # Clean architecture check (.NET)
└── profiles/
    ├── minimal.toml        # Shared rules + commit skill only
    ├── react-full-stack.toml   # Frontend rules + recommended plugins
    └── dotnet-enterprise.toml  # Backend rules + all skills
```

### How defaults merge with content

The engine scans both `engine/defaults/` and the content repo root. Items from both locations appear in the installer menus. For example, if defaults provide a `security` rule and your content repo also provides a `security` rule, both are discovered — but files with the same name in the same category directory are deduplicated, with the **content repo version taking precedence**.

### Disabling defaults

Turn off any category in `kit.toml`:

```toml
[defaults]
rules = true       # Keep default rules
skills = true      # Keep default skills
registry = false   # Use ONLY my registry.toml
profiles = false   # Use ONLY my profiles
```

## Features

### Interactive TUI

Full terminal UI with color themes, animated menus, checkbox selection, fuzzy search, and keyboard navigation. Works in any terminal that supports ANSI escape codes.

### 10 built-in themes + custom themes

Switch themes live with `t`. Custom themes defined in `kit.toml` appear first.

### Profile presets

One-click presets that pre-select rules, skills, and plugins. Three built-in profiles ship with the engine defaults, and content repos can add their own as `.toml` files in `profiles/`.

### Stack detection

The engine scans the target project for file patterns (e.g. `package.json` for React, `*.csproj` for .NET) and auto-selects matching stacks. Stacks determine which rule categories are shown.

### Team config sharing

After installing, users can export their selections to a `.{watermark}-config` file. When another team member runs the installer in the same project, the engine detects the config file and offers to apply it.

### Fuzzy search

Press `/` in any checkbox menu to filter items by fuzzy matching. Press `Esc` to clear the search.

### Token budget estimates

Every rule and skill shows an estimated token count. The footer displays a running total of tokens that will be added to the AI's context. Color-coded: green for light, yellow for moderate, red for heavy.

### File safety

No overwrites without backups. No deletions of custom content. Watermarked files are tracked; everything else is left untouched.

### Multi-tool support

One install configures Claude Code, Gemini CLI, Codex, Windsurf, Continue.dev, GitHub Copilot, and Cursor simultaneously.

### Global + project install modes

Project mode installs into the current repo. Global mode creates symlinks from a central location to each AI tool's config directory.

### Manage mode

After initial install, run again to add, remove, or update individual items without reinstalling everything.

### Dry run mode

Preview exactly what would be installed without writing any files.

## Built-in themes

| Theme | Style |
|-------|-------|
| Tokyo Night | Cool blues and purples |
| Monokai Pro | Warm oranges and greens |
| GitHub Dark | GitHub's dark palette |
| Rider Dark | JetBrains Rider inspired |
| Dracula | Classic purple and pink |
| One Dark | Atom editor colors |
| Catppuccin | Pastel warmth |
| Nord | Arctic blue tones |
| Gruvbox | Retro warm earth tones |
| Solarized | Ethan Schoonover's classic |

Custom themes defined via `[[custom_themes]]` in `kit.toml` appear before these in the picker.

## CLI flags

| Flag | Description |
|------|-------------|
| `--help`, `-h` | Show usage information |
| `--check` | Verify installed rules/skills are in sync with kit source |
| `--update` | Re-install, overwriting existing rules/skills with latest |
| `--uninstall` | Remove all kit-installed files (with backup restoration) |
| `--list` | Show installed rules, skills, and plugins |
| `--dry-run` | Show what would be installed without making changes |
| `--kit-dir <path>` | Path to content repo (set by wrapper, not for manual use) |
| `--windows` | Simulate Windows mode (for testing on macOS/Linux) |

Flags are passed through the wrapper script:

```bash
bash install.sh --check
bash install.sh --dry-run
bash install.sh --uninstall
```

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| `t` | Open theme picker |
| `/` | Start fuzzy search |
| `Space` | Toggle item on/off |
| `Enter` | Confirm selection |
| `b` or `Left` | Go back |
| `Esc` | Clear search filter |
| `Up` / `Down` | Navigate items |

## Adding content

| Want to add... | How |
|----------------|-----|
| A rule | Create `rules/{category}/{name}.md` in your content repo |
| A skill | Create `skills/{name}/SKILL.md` in your content repo |
| A plugin | Add `[plugins.name]` section to `registry.toml` |
| An MCP server | Add `[mcps.name]` section to `registry.toml` |
| A profile | Create `profiles/{name}.toml` in your content repo |
| A custom theme | Add `[[custom_themes]]` block to `kit.toml` |
| A stack | Add `[stacks.key]` section to `kit.toml` |

### Profile format

```toml
name = "My Profile"
description = "What this profile includes"
stacks = ["react", "integrations"]

[rules]
items = ["commit-conventions", "security", "typescript", "components"]

[skills]
items = ["commit", "create-pr", "review"]

[plugins]
items = ["superpowers", "coderabbit"]
```

### Registry format

```toml
[plugins.my-plugin]
tokens = 500          # Optional: estimated token cost
heavy = true          # Optional: flag as heavy (shown in yellow)
stack = "react"       # Optional: only shown when this stack is selected

[mcps.my-server]
url = "https://example.com/mcp"   # HTTP/SSE URL or npx command
```

For `npx`-based MCP servers, use colon-separated arguments:

```toml
[mcps.context7]
url = "npx:-y:@upstash/context7-mcp"
```

## AI tool support

| Tool | Config path | Symlink support |
|------|-------------|-----------------|
| Claude Code | `~/.claude/` | Yes |
| Gemini CLI | `~/.gemini/` | Yes |
| Codex CLI | `~/.codex/` | Yes |
| Windsurf | `~/.codeium/windsurf/memories/` | Yes |
| Continue.dev | `~/.continue/rules/` | Yes |
| GitHub Copilot | `.github/copilot-instructions.md` | Project only |
| Cursor | `.cursor/rules/` | Project only |

Tools with symlink support can be configured globally. Tools without symlink support are configured per-project only.

## Token budget

The engine estimates token cost for every rule and skill by counting words and applying a multiplier (~1.3 tokens per word). These estimates appear in checkbox menus so you can make informed decisions about context size.

You only pay for what you install. A minimal setup (4 shared rules + commit skill) adds roughly 2,000 tokens. A full enterprise setup with all stacks might add 15,000-20,000 tokens.

| Category | Typical range |
|----------|--------------|
| Single rule | 200-800 tokens |
| Single skill | 500-2,000 tokens |
| Plugin (heavy) | 1,500-3,000 tokens |
| Minimal profile | ~2,000 tokens total |
| Full profile | ~12,000-18,000 tokens total |

## File safety

- **No overwrites** — existing files are backed up as `{file}.before-{watermark}` before being replaced
- **No deletions of custom content** — only files watermarked by the engine are touched during uninstall
- **`--dry-run` preview** — see exactly what would happen before committing to an install
- **Clean uninstall** — `--uninstall` removes kit files and restores `.before-{watermark}` backups
- **Watermarked files** — installed files contain a marker comment so the engine knows what it owns
- **Backup restoration** — if a file existed before the kit was installed, uninstall brings it back

## Examples

### Minimal kit — just branding, use all defaults

```toml
# kit.toml
[branding]
name = "Acme AI Kit"
short_name = "ACME"
tagline = "AI standards for Acme Engineering"
watermark = "acme-ai-kit"
config_dir = ".acme"
```

This gives you all default rules, skills, profiles, and registry with Acme branding. The `Tokyo Night` theme is used by default. No custom stacks, no custom themes.

### Moderate — branding + custom theme + custom stacks

```toml
# kit.toml
[branding]
name = "Contoso Dev Kit"
short_name = "CONTOSO"
tagline = "Standardized AI tooling for Contoso"
watermark = "contoso-dev-kit"
config_dir = ".contoso"
ascii_art_file = "branding/logo.txt"

[settings]
default_theme = "Contoso Blue"

[[custom_themes]]
name = "Contoso Blue"
lime = [0, 120, 212]
teal = [80, 180, 220]
gold = [255, 185, 0]

[stacks.python]
name = "Python / FastAPI / Django"
detect = ["requirements.txt", "pyproject.toml", "Pipfile"]
rules_dir = "python"

[stacks.react]
name = "React / Next.js"
detect = ["package.json"]
rules_dir = "react"

[defaults]
rules = true
skills = true
registry = false
profiles = true
```

### Full — everything customized

```toml
# kit.toml
[branding]
name = "Mega Corp AI Kit"
short_name = "MEGA"
tagline = "Enterprise AI development standards"
watermark = "mega-ai-kit"
config_dir = ".mega"
ascii_art_file = "branding/mega-logo.txt"

[settings]
default_theme = "Mega Dark"

[defaults]
rules = true
skills = true
registry = true
profiles = true

[[custom_themes]]
name = "Mega Dark"
lime = [140, 220, 100]
teal = [100, 180, 255]
gold = [255, 200, 80]

[[custom_themes]]
name = "Mega Light"
lime = [60, 140, 40]
teal = [30, 100, 180]
gold = [200, 160, 40]

[stacks.react]
name = "React / Next.js / React Native"
detect = ["package.json", "tsconfig.json"]
rules_dir = "react"

[stacks.dotnet]
name = ".NET / C#"
detect = ["*.csproj", "*.sln"]
rules_dir = "dotnet"

[stacks.python]
name = "Python / FastAPI"
detect = ["pyproject.toml", "requirements.txt"]
rules_dir = "python"

[stacks.go]
name = "Go"
detect = ["go.mod"]
rules_dir = "go"

[stacks.integrations]
name = "Integrations (GitHub, Jira, Azure DevOps)"
rules_dir = "integrations"

[wrapper_files]
items = ["CLAUDE.md", "COPILOT.md", "CURSOR.md", "CODEX.md", "GEMINI.md"]

[global_symlinks.claude]
name = "Claude Code"
cli = "claude"
paths = [
    { src = "CLAUDE.md", dst = "~/.claude/CLAUDE.md" },
    { src = ".claude/rules/", dst = "~/.claude/rules/" },
    { src = ".claude/skills/", dst = "~/.claude/skills/" },
]

[global_symlinks.gemini]
name = "Gemini CLI"
cli = "gemini"
alt_cli = "antigravity"
paths = [
    { src = "GEMINI.md", dst = "~/.gemini/GEMINI.md" },
    { src = "AGENT.md", dst = "~/.gemini/AGENT.md" },
]

[global_symlinks.codex]
name = "Codex CLI"
cli = "codex"
paths = [
    { src = "CODEX.md", dst = "~/.codex/AGENTS.md" },
    { src = "AGENT.md", dst = "~/.codex/AGENT.md" },
]

[global_symlinks.windsurf]
name = "Windsurf"
paths = [
    { src = "AGENT.md", dst = "~/.codeium/windsurf/memories/global_rules.md" },
]

[global_symlinks.continue]
name = "Continue.dev"
paths = [
    { src = ".claude/rules/", dst = "~/.continue/rules/" },
]
```

## Engine defaults directory

```
engine/defaults/
├── kit.toml                        # Reference configuration (copy to your repo)
├── registry.toml                   # Plugins: coderabbit, superpowers, ui-ux-pro-max,
│                                   #   commit-commands, typescript-lsp, csharp-lsp
│                                   # MCPs: context7, atlassian, figma
├── rules/
│   ├── shared/
│   │   ├── commit-conventions.md
│   │   ├── database.md
│   │   ├── logging.md
│   │   ├── no-auto-push.md
│   │   ├── plan-refinement.md
│   │   └── security.md
│   ├── react/
│   │   ├── accessibility.md
│   │   ├── api-integration.md
│   │   ├── components.md
│   │   ├── internationalization.md
│   │   ├── no-hardcoded-colors.md
│   │   ├── responsive-web-ui.md
│   │   └── typescript.md
│   ├── dotnet/
│   │   ├── clean-architecture.md
│   │   ├── cqrs-mediatr.md
│   │   ├── csharp.md
│   │   ├── domain-models.md
│   │   ├── error-handling.md
│   │   ├── persistence-entities.md
│   │   └── repository-query-pattern.md
│   └── integrations/
│       ├── azure-devops.md
│       ├── bitbucket.md
│       ├── github.md
│       └── jira.md
├── skills/
│   ├── add-migration/SKILL.md
│   ├── commit/SKILL.md
│   ├── create-pr/SKILL.md
│   ├── debug/SKILL.md
│   ├── document/SKILL.md
│   ├── new-issue/SKILL.md
│   ├── refactor/SKILL.md
│   ├── review/SKILL.md
│   └── validate-architecture/SKILL.md
└── profiles/
    ├── minimal.toml                # Shared rules + commit skill
    ├── react-full-stack.toml       # Frontend rules + recommended plugins
    └── dotnet-enterprise.toml      # Backend rules + all skills
```

## For engine contributors

### Ground rules

- **Never hardcode brand names** — all branding comes from `kit.toml`
- **Never break backward compatibility** — content repos auto-update the submodule; existing `kit.toml` files must continue working
- **Every commit bumps `VERSION`** — see `.claude/rules/versioning.md`
- **New `kit.toml` fields must have defaults** — the engine must work with a minimal or empty `kit.toml`
- **Default content must be universally applicable** — no brand-specific references in `defaults/`
- **Never auto-push** — committing locally is fine; pushing requires explicit permission

### Development rules

Full rules are in `.claude/rules/`:

| Rule | Purpose |
|------|---------|
| `engine-scope.md` | Keep the engine generic — no brand-specific content |
| `no-breaking-changes.md` | Backward compatibility contract |
| `versioning.md` | Semantic version bump on every commit |
| `no-auto-push.md` | Never push without explicit permission |

### Testing changes

Test against at least one content repo before pushing:

```bash
cd ../my-ai-kit
bash install.sh --dry-run
bash install.sh
bash install.sh --check
bash install.sh --uninstall
```

## License

MIT
