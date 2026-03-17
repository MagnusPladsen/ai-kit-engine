# Profile Sync

When adding, removing, or renaming rules, skills, plugins, or MCP servers in `defaults/`:

1. Update ALL profile TOML files in `defaults/profiles/` to include/remove the item
2. Place new items in the appropriate profile(s) based on their category:
   - **Shared rules** (in `defaults/rules/shared/`) → add to ALL profiles
   - **React rules** (in `defaults/rules/react/`) → add to `react-full-stack.toml`
   - **.NET rules** (in `defaults/rules/dotnet/`) → add to `dotnet-enterprise.toml`
   - **Integration rules** (in `defaults/rules/integrations/`) → add to profiles that have `stacks = [..., "integrations"]`
   - **Generic skills** → add to `react-full-stack.toml` and `dotnet-enterprise.toml`; add to `minimal.toml` only if fundamental
   - **Stack-specific skills** (e.g. `add-migration`) → only the matching profile
   - **Plugins with `stack = "react"`** → `react-full-stack.toml`
   - **Plugins with `stack = "dotnet"`** → `dotnet-enterprise.toml`
   - **Generic plugins** → both full profiles; `minimal.toml` only if zero-cost
3. When adding to `registry.toml`, check which profiles should include the new entry
4. Verify by diffing profile items against `defaults/rules/`, `defaults/skills/`, and `defaults/registry.toml`
