# Testing Standards

- Use Vitest as the test runner, React Testing Library for component tests
- Test behavior, not implementation — query by role, label, or text, never by class/id
- Every new component must have a corresponding `*.test.tsx` file
- Aim for 80% coverage on business logic; UI coverage is a bonus, not a target
- Use `msw` (Mock Service Worker) for API mocking — no manual fetch mocks
- Integration tests for critical user flows (auth, checkout, forms)
- Run `npm test` before every commit — broken tests block merging
- Snapshot tests are discouraged — prefer explicit assertions
