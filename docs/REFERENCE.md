# AI Kit Engine -- Full Reference

This document contains the complete reference for `kit.toml` configuration, example configs, the defaults system, wrapper script internals, and detailed feature documentation.

For a quick overview, see the [README](../README.md).

## Table of contents

- [Full kit.toml reference](#full-kittoml-reference)
- [Wrapper install.sh explained](#wrapper-installsh-explained)
- [Defaults system](#defaults-system)
- [Engine defaults directory](#engine-defaults-directory)
- [Example configs](#example-configs)
- [AI tool support](#ai-tool-support)
- [Token budget](#token-budget)
- [File safety](#file-safety)
- [Built-in themes](#built-in-themes)
- [CLI flags](#cli-flags)
- [Keyboard shortcuts](#keyboard-shortcuts)

---

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
| `detect` | array | File glob patterns -- if any match in the project root, the stack is auto-selected |
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

---

## Wrapper `install.sh` explained

The wrapper script is intentionally minimal (~10 lines). Here is what each section does:

```bash
#!/bin/bash
# My AI Kit -- Installer
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

# Copy engine to temp file to avoid race conditions with lazy bash reads
_ENGINE_TMP="$(mktemp)"
cp "$ENGINE" "$_ENGINE_TMP"
trap 'rm -f "$_ENGINE_TMP"' EXIT

exec bash "$_ENGINE_TMP" --kit-dir "$SCRIPT_DIR" "$@"
```

### Section breakdown

**Auto-init submodule:** On first clone, users may not have run `git submodule update`. The wrapper handles this automatically.

**Copy to temp file:** Bash reads scripts lazily. Copying to a temp file prevents issues if the engine file changes mid-execution.

**`--kit-dir` flag:** Tells the engine where to find `kit.toml`, rules, skills, and other content. All other flags are passed through.

**Engine update check:** The engine itself checks for submodule updates on startup (in wrapper mode). If a new version is available, it prompts with an arrow-key menu to update now or skip.

---

## Defaults system

The `engine/defaults/` directory contains generic, universally applicable starter content. When a content repo sets `[defaults].rules = true` (the default), the engine merges these defaults with the content repo's own rules, skills, profiles, and registry.

### How defaults merge with content

The engine scans both `engine/defaults/` and the content repo root. Items from both locations appear in the installer menus. Files with the same name in the same category directory are deduplicated, with the **content repo version taking precedence**.

### Disabling defaults

Turn off any category in `kit.toml`:

```toml
[defaults]
rules = true       # Keep default rules
skills = true      # Keep default skills
registry = false   # Use ONLY my registry.toml
profiles = false   # Use ONLY my profiles
```

---

## Engine defaults directory

```
engine/defaults/
├── kit.toml                        # Reference configuration (copy to your repo)
├── registry.toml                   # Plugins: coderabbit, superpowers, ui-ux-pro-max,
│                                   #   commit-commands, typescript-lsp, csharp-lsp
│                                   # MCPs: context7, atlassian, figma
├── rules/
│   ├── shared/
│   │   ├── code-quality.md
│   │   ├── commit-conventions.md
│   │   ├── database.md
│   │   ├── dependency-management.md
│   │   ├── design-consistency.md
│   │   ├── logging.md
│   │   ├── minimal-diff.md
│   │   ├── naming-conventions.md
│   │   ├── no-auto-push.md
│   │   ├── no-phantom-code.md
│   │   ├── plan-refinement.md
│   │   ├── pr-conventions.md
│   │   ├── reusable-code.md
│   │   ├── security.md
│   │   └── testing-conventions.md
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
│   ├── changelog/SKILL.md
│   ├── commit/SKILL.md
│   ├── create-pr/SKILL.md
│   ├── debug/SKILL.md
│   ├── document/SKILL.md
│   ├── new-issue/SKILL.md
│   ├── onboard/SKILL.md
│   ├── refactor/SKILL.md
│   ├── review/SKILL.md
│   ├── test/SKILL.md
│   └── validate-architecture/SKILL.md
└── profiles/
    ├── minimal.toml                # Shared rules + commit skill
    ├── react-full-stack.toml       # Frontend rules + recommended plugins
    └── dotnet-enterprise.toml      # Backend rules + all skills
```

---

## Example configs

### Minimal -- just branding, use all defaults

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

### Moderate -- branding + custom theme + custom stacks

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

### Full -- everything customized

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

---

## AI tool support

| Tool | Config path | Symlink support |
|------|-------------|-----------------|
| Claude Code | `~/.claude/` | Yes |
| Gemini CLI | `~/.gemini/` | Yes |
| Codex CLI | `~/.codex/` | Yes |
| OpenCode | `~/.config/opencode/` | Yes |
| Crush | `~/.config/crush/` | Yes |
| Windsurf | `~/.codeium/windsurf/memories/` | Yes |
| Continue.dev | `~/.continue/rules/` | Yes |
| GitHub Copilot | `.github/copilot-instructions.md` | Project only |
| Cursor | `.cursor/rules/` | Project only |

Tools with symlink support can be configured globally. Tools without symlink support are configured per-project only.

---

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

---

## File safety

- **No overwrites** -- existing files are backed up as `{file}.before-{watermark}` before being replaced
- **No deletions of custom content** -- only files watermarked by the engine are touched during uninstall
- **`--dry-run` preview** -- see exactly what would happen before committing to an install
- **Clean uninstall** -- `--uninstall` removes kit files and restores `.before-{watermark}` backups
- **Watermarked files** -- installed files contain a marker comment so the engine knows what it owns
- **Backup restoration** -- if a file existed before the kit was installed, uninstall brings it back

---

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

---

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

---

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
