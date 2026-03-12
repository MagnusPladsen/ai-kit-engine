---
description: Version bump rule — triggers on any commit or push workflow
alwaysApply: true
---

# Version Bump Rule

Every commit to this repository MUST increment the version number in the `VERSION` file at the project root.

## Format

The version follows `MAJOR.MINOR.PATCH`:

- **PATCH** (1.2.1 → 1.2.2) — bug fixes, cosmetic changes, README edits, new default rules/skills
- **MINOR** (1.2.2 → 1.3.0) — new features: new kit.toml fields, new TUI functionality, new flags
- **MAJOR** (1.3.0 → 2.0.0) — breaking changes to kit.toml format, defaults structure, or --kit-dir contract (see no-breaking-changes rule — avoid these)

## Workflow

1. Before committing, read the current version from `VERSION`
2. Bump the appropriate segment based on the change size
3. Stage the updated `VERSION` file alongside your other changes
4. Include the new version in the commit message, e.g.: `v1.0.1: Add fallback for missing ascii_art_file`

## Important

- Never skip this step — every single commit must bump the version
- If multiple changes are bundled in one commit, pick the highest applicable bump level
- MAJOR bumps should be extremely rare — see no-breaking-changes rule
