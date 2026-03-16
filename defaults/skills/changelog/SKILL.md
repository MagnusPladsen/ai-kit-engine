---
name: changelog
description: Generate or update CHANGELOG from git history
---

# /changelog — Generate Changelog

Generate or update CHANGELOG.md from git history.

## Steps

1. **Determine range** — ask the user or detect automatically:
   - Between two tags: `git log v1.0.0..v1.1.0 --oneline`
   - Since last tag: `git log $(git describe --tags --abbrev=0)..HEAD --oneline`
   - All history: `git log --oneline`

2. **Categorize commits** by prefix:
   - `feat:` / `add:` → **Added**
   - `fix:` / `bugfix:` → **Fixed**
   - `change:` / `update:` / `refactor:` → **Changed**
   - `remove:` / `deprecate:` → **Removed**
   - `docs:` → **Documentation**
   - `perf:` → **Performance**
   - Other → **Other**

3. **Format** using [Keep a Changelog](https://keepachangelog.com/) style:
   ```markdown
   ## [1.1.0] - 2025-03-15

   ### Added
   - Feature description

   ### Fixed
   - Bug fix description
   ```

4. **Write or update** CHANGELOG.md:
   - If file exists, prepend the new section after the header
   - If file doesn't exist, create it with a header

5. **Show the result** and ask if the user wants to adjust anything

## Important

- Keep descriptions concise and user-facing — not raw commit messages
- Group related commits into single entries where appropriate
- Skip merge commits and version bump commits
