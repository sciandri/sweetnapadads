# Testing strategy

## Layers

- **Unit:** deterministic domain rules, money handling, scoring, ties, and
  payout allocation with Vitest.
- **Database:** migrations, constraints, functions, triggers, and RLS against a
  local Supabase instance.
- **Integration:** Route Handlers and ESPN normalization using recorded,
  redacted fixtures.
- **End-to-end:** login, member balance inspection, commissioner sync, and
  payment recording with Playwright.
- **Reconciliation:** 2025 accepted outputs compared to imported source totals.

## Required local checks

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

CI will run the same checks. Financial and authorization changes require tests
at their owning layer.
