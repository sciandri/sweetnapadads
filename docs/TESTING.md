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
layer. The development-seed contract verifies the synthetic commissioner,
league, season rules, and commissioner authorization after every local reset.

Supabase environment parsing is unit-tested without real credentials. Auth
route tests must use synthetic identities and must cover expired sessions,
cookie refresh, login failure, and authorization denial before authenticated
screens ship.

The current Auth suite covers email normalization, local-only redirect
validation, supported email callback types, PKCE exchange, token-hash
verification, and generic expired-link handling. Database RLS tests cover
member, commissioner, and outsider authorization. Finance pgTAP coverage
verifies immutable events, source-key idempotency, compatible settlement
directions, payment and obligation allocation caps, reversible allocations,
audited adjustment reasons, exact reconciliation equations, canonical
team-perspective balances, and league-scoped view visibility.
Historical-import pgTAP coverage verifies lossless duplicate-row preservation,
immutable source evidence, mapping and blocker approval gates, terminal review
states, and commissioner-only staging access. The application suite also
checks that the 2025 workbook checksum and eight-sheet manifest remain exact.
It also requires an approved treatment for every manifest issue, verifies the
arithmetic of each champion-payout option, and reconciles the review-only
normalized preview without committing domain rows.
