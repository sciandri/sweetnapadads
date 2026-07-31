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
npm run db:reset
npm run db:lint
npm run db:test
npm run build
```

Database tests live in `supabase/tests/database/` and run with pgTAP against
the local Supabase PostgreSQL container. `db:lint` treats PostgreSQL warnings
as failures. Financial and authorization changes require tests at their owning
layer.

Supabase environment parsing is unit-tested without real credentials. Auth
route tests must use synthetic identities and must cover expired sessions,
cookie refresh, login failure, and authorization denial before authenticated
screens ship.
