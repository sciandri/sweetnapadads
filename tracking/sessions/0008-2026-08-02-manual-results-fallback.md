# Session 0008 — Completion release candidate

- Date: 2026-08-02
- Status: completed
- Branch: `main`
- Starting commit: `169fc50`
- Ending source commit: `64bf20a`

## Goal

Complete the remaining local MVP checklist while preserving competition,
financial, authentication, and operational audit boundaries.

## Starting context

Session 0007 published the member finance, team-history, and activity surfaces.
ESPN competition ingestion already preserves immutable raw evidence and writes
reciprocal results atomically. Manual results are the next canonical checklist
item and must not overwrite imported or ESPN source facts.

## Work completed

- [x] Confirm clean, synchronized `main` at `169fc50` in the relocated local
      workspace.
- [x] Re-read canonical tracking, the project foundation, competition schema,
      award derivation, commissioner API contract, current Supabase guidance,
      and relevant Postgres security/locking practices.
- [x] Add an immutable manual-result batch with actor, reason, request key,
      normalized payload hash, source links, composite constraints, and RLS.
- [x] Add the locked commissioner-only `record_manual_week_results` boundary
      with exact active-team coverage, reciprocal outcomes, idempotency, and
      configured weekly award derivation.
- [x] Revoke direct authenticated inserts into matchups, weekly results, and
      weekly awards.
- [x] Add strict request parsing, a stable redacted Route Handler, and unit and
      HTTP coverage.
- [x] Add the responsive season-aware commissioner form and dashboard link.
- [x] Document the operational boundary and update canonical tracking.
- [x] Add immutable accepted-week corrections, accepted projections, and
      audited award/obligation reconciliation.
- [x] Add authenticated Playwright critical paths for desktop and 390px mobile.
- [x] Add scheduled ESPN workflow scaffolding, health/telemetry, and incident
      runbooks.
- [x] Add immutable in-app notifications with delivery evidence.
- [x] Add the server-only OpenAI Responses boundary and three editable composer
      options with a safe missing-key state.
- [x] Configure custom Resend SMTP, accept the first production commissioner
      invitation, attach the confirmed identity to the canonical league, and
      create a neutral 2026 setup season so authenticated navigation works.
- [x] Close inherited anonymous execution on the historical-import and
      commissioner-message security-definer RPCs, including a conditional
      revoke for Supabase's hosted-only RLS event trigger.
- [x] Stage all 533 workbook rows, receive explicit final approval, commit the
      production 2025 preview, verify its exact retry, counts, reconciliation,
      and 390 provenance links.
- [x] Close the raw-only side-bet gap with an immutable RLS model and member
      Activity UI that preserves both `$20` records without inventing outcomes,
      settlement, or dates.

## Decisions

- Missing-week and correction evidence are separate immutable operations.
- Accepted projections choose the current truth without deleting source rows;
  financial corrections remain append-only.
- The database derives outcomes and configured weekly awards; the browser does
  not submit either as authority.
- Team count comes from active season teams, preserving ten- and twelve-team
  support without an application constant.

## Verification

- `npm run lint`: passing
- `npm run typecheck`: passing
- `npm test`: 126 tests passing across 30 files
- `npm run db:reset`: passing
- `npm run db:lint`: passing with no warnings
- `npm run db:test`: 405 database tests passing across 21 files
- `npm run build`: passing with the API and commissioner page as dynamic routes
- `npm run tracking:check`: passing with eight session logs
- Local production-build smoke: `/login` returns HTTP 200 and the unauthenticated
  commissioner route redirects exactly to
  `/login?next=/dashboard/admin/results`
- Playwright: 7 critical paths passing across desktop and 390px mobile; one
  intentional desktop skip for a mobile-only overflow assertion
- Canonical import: first local run committed and reconciled; second full run
  and the internal retry both returned `already_committed`
- GitHub `main`: source checkpoint `64bf20a` published and synchronized
- Hosted Supabase: all twenty-one migrations through `20260802183000` applied;
  post-apply dry-run reports no migration, seed, or role changes
- Production 2025 import: 533 source rows, 80 matchups, 160 results, 14 awards,
  49 obligations, 43 payments, 43 allocations, one external cash event, and
  390 provenance links; reconciliation is `$240` cash and `$40` net team
  balance
- Spreadsheet activity: both `$20` side bets are committed with exact parties,
  descriptions, and `Bets!A2:D2` / `Bets!A3:D3` source references
- Vercel production `dpl_5ZmJ2YT327evXjcxfsrLzxx9VtiV`: Ready and aliased to
  `https://www.sweetnapadads.com`
- Production smoke: home, login, and `/api/health` return HTTP 200; signed-out
  activity and ESPN controls preserve their exact safe login return paths

## Risks or blockers

- Rotate the Resend credential before another invitation because it appeared
  in an operator-only verification transcript.
- Live AI drafting remains intentionally disabled until `OPENAI_API_KEY` is
  configured server-side and a provider smoke test passes.
- Production ESPN synchronization remains intentionally disabled until ESPN
  credentials, `SYNC_SECRET`, reviewed 2026 mappings, and workflow values are
  configured in their documented scopes.
- The neutral 2026 setup season still needs its real ten- or twelve-team roster
  and commissioner-approved season rules before league play begins.

## Exact handoff

Start the next session from clean, synchronized `main`. Rotate the Resend key
before inviting anyone else, then configure and smoke-test OpenAI or complete
the real 2026 roster, mappings, and season rules.
