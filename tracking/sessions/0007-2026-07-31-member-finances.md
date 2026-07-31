# Session 0007 — Member transparency and record book

- Date: 2026-07-31
- Status: active
- Branch: `main`
- Starting commit: `d3b272e`
- Ending source commit: pending

## Goal

Build authenticated, mobile-first member evidence surfaces where league users
can explain balances, browse durable team history, and review season activity
from canonical competition and financial records.

## Starting context

Session 0006 published ESPN competition synchronization, audited financial-rule
configuration, member standings, results, and weekly honors. Finance event
tables and security-invoker reconciliation views are already implemented and
tested; this session exposes them without duplicating ledger calculations.

## Work completed

- [x] Confirm clean, synchronized `main` at `d3b272e`.
- [x] Re-read canonical tracking, the project foundation, finance contract,
      canonical views, event schema, and RLS policies.
- [x] Add deterministic balance labeling, summary grouping, and immutable event
      reconciliation presentation with unit coverage.
- [x] Build `/dashboard/finances` with season selection, league cash summary,
      league-wide team balances, selected balance components, and source events.
- [x] Add member dashboard navigation to the finance surface.
- [x] Verify the seeded development ledger and locally rehearsed ten-team 2025
      finance record at desktop and 390px widths.
- [x] Add deterministic franchise season summaries and dated ownership history
      with unit coverage.
- [x] Build the season-scoped `/dashboard/teams` directory and durable
      `/dashboard/teams/[teamId]` record pages.
- [x] Link franchise seasons back to their result and financial evidence.
- [x] Verify seeded ownership, the rehearsed ten-team directory, a populated
      franchise record, missing-owner honesty, and 390px detail layout.
- [x] Add deterministic competition and financial activity presentation models
      with unit coverage.
- [x] Build `/dashboard/activity` with season selection and separate week-based
      competition and date-based financial timelines.
- [x] Add member dashboard navigation to the activity surface.
- [x] Verify seeded finance-only and populated 2025 activity at desktop and
      390px widths.

## Decisions

- Treat PostgreSQL reconciliation and balance views as canonical; application
  code may label and group their outputs but may not recalculate balances.
- Keep competition and finance as separate activity streams because their
  ordering and event semantics are not interchangeable.

## Verification

- `npm run lint`: passing.
- `npm run typecheck`: passing.
- `npm test`: 99 tests passing.
- Seeded development view: $50 actual cash, $140 team balance, exact six-part
  component explanation, and three source events.
- Rehearsed 2025 view: $240 actual cash, $40 teams owe, no league-owed balance,
  and nine of ten teams settled.
- Browser review: populated desktop and 390px mobile layouts pass.
- Team history browser review: seeded current owner plus populated ten-team 2025
  directory and franchise statistics pass at desktop and 390px widths.
- Activity browser review: seeded financial-only state plus populated 2025
  matchups, honors, obligations, and payments pass at desktop and 390px widths.

## Risks or blockers

- Hosted 2025 history remains intentionally absent, so production will show
  honest empty financial states until real season events are authorized.

## Exact handoff

Continue with the manual-results fallback while preserving the same accepted
competition invariants and configured financial-rule derivation.
