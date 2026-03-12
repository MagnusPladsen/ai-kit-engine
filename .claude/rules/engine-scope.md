---
description: Keep engine generic — no brand-specific content
globs: ["install.sh", "defaults/**"]
alwaysApply: true
---

# Engine Scope

This repo is a generic TUI engine. It must never contain brand-specific content.

## Rules

- NEVER hardcode any brand name, company name, or product name in install.sh
- All branding comes from kit.toml — the engine reads it, never defines it
- The defaults/ directory contains generic starter content usable by anyone
- Default rules/skills must be universally applicable (commit conventions, security, etc.)
- Default rules/skills must NOT reference specific companies, Jira projects, Azure DevOps orgs, or internal tools
- Built-in themes are generic (Tokyo Night, Dracula, etc.) — brand themes go in kit.toml's [[custom_themes]]
