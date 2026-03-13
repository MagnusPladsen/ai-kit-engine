# /deploy — Deployment Workflow

Guided deployment skill for Contoso services.

## Steps

1. **Confirm target environment** — ask the user: staging or production?
2. **Run pre-deploy checks:**
   - Ensure all tests pass (`dotnet test` or `npm test`)
   - Ensure no uncommitted changes (`git status --porcelain`)
   - Ensure branch is up to date with remote
3. **Build the artifact:**
   - .NET: `dotnet publish -c Release -o ./publish`
   - React: `npm run build`
4. **Tag the release:**
   - Format: `v{version}-{environment}-{date}` (e.g. `v1.2.3-staging-20260313`)
   - Create git tag but do NOT push unless user confirms
5. **Generate deployment summary:**
   - List commits since last deployment tag
   - List changed files
   - Note any migration changes
6. **Hand off** — print the deployment command for the user to run manually:
   - Staging: `az webapp deploy --name contoso-api-staging ...`
   - Production: `az webapp deploy --name contoso-api-prod ...`

## Important

- Never deploy directly — always generate the command for the user to review and execute
- Production deployments require explicit user confirmation at every step
- If tests fail, stop immediately and report the failures
