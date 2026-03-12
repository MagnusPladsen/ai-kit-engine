---
description: Backward compatibility contract — triggers on any edit to install.sh, kit.toml parsing, or defaults/
globs: ["install.sh", "defaults/**"]
alwaysApply: true
---

# No Breaking Changes

The install.sh engine is used by multiple content repos via git submodule.
Breaking the kit.toml format, defaults structure, or --kit-dir contract
will silently break all downstream users with no warning.

## Rules

- NEVER rename or remove kit.toml fields — only add new ones with sensible defaults
- NEVER change the defaults/ directory structure — only add new files
- NEVER change the --kit-dir flag behavior or argument format
- NEVER remove built-in themes — only add new ones
- NEVER change the watermark format — only extend it
- NEVER change how the wrapper install.sh calls the engine
- New kit.toml fields MUST have sensible defaults so existing kit.toml files
  continue to work without changes
- All changes must be backward-compatible: a content repo that worked yesterday
  must work today without modifications
- If a change MUST break compatibility, it requires a MAJOR version bump and
  must be documented in CHANGELOG.md with migration instructions

## Why

Content repos pin the engine as a submodule. Their wrapper does background
`submodule update --remote` which pulls the latest engine automatically.
A breaking change silently breaks every content repo on their next run.
There is no way to coordinate updates across independent repos.
