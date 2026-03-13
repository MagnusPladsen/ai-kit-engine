# Example Kit Setups

Complete, ready-to-copy example configurations for the AI Kit Engine. Each directory is a self-contained kit that you can use as a starting point.

## Examples

| Example | Description |
|---------|-------------|
| [`minimal/`](minimal/) | Bare minimum kit — just branding, all engine defaults enabled |
| [`startup/`](startup/) | Small startup with React + Python stacks, custom theme, and a profile |
| [`enterprise/`](enterprise/) | Large enterprise with all stacks, multiple themes, custom symlinks, wrapper files, profiles, and a custom skill |
| [`single-stack/`](single-stack/) | Solo developer with a single Go stack, engine defaults disabled for skills |

## Usage

1. **Pick an example** that matches your team size and stack.
2. **Copy the directory** to a new git repo:
   ```bash
   cp -r docs/examples/startup/ ~/git/my-team-kit/
   cd ~/git/my-team-kit/
   git init
   ```
3. **Add the engine as a submodule:**
   ```bash
   git submodule add https://github.com/user/ai-kit-engine.git engine
   ```
4. **Customize `kit.toml`** — update branding, stacks, and themes to match your team.
5. **Add your own rules** in `rules/` and skills in `skills/`.
6. **Run the installer:**
   ```bash
   bash install.sh
   ```

## What each file does

| File | Purpose |
|------|---------|
| `kit.toml` | All configuration — branding, stacks, themes, defaults, symlinks |
| `install.sh` | Thin wrapper (~15 lines) that delegates to the engine submodule |
| `branding/ascii.txt` | ASCII art logo displayed in the installer TUI |
| `rules/<stack>/*.md` | Convention rules installed into target projects |
| `skills/<name>/SKILL.md` | Custom slash-command skills for AI assistants |
| `profiles/*.toml` | Preset configurations that pre-select rules, skills, and plugins |
| `registry.toml` | Plugin and MCP server definitions |

## Further reading

- [Main README](../../README.md) — project overview and quickstart
- [Full Reference](../REFERENCE.md) — complete `kit.toml` reference, CLI flags, and feature documentation
