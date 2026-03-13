# State Management

- Use Zustand for global client state — no Redux
- Use React Query (TanStack Query) for all server state
- Keep component-local state in `useState` when it does not need to be shared
- Never store derived state — compute it from source data
- Avoid prop drilling beyond 2 levels — use Zustand or context instead
- Zustand stores go in `src/stores/` with the naming convention `use{Name}Store.ts`
