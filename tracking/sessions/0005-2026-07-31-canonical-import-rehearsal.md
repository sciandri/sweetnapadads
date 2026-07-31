# Session 0005 — Canonical 2025 import rehearsal

- Date: 2026-07-31
- Status: complete — published and deployed
- Branch: `main`
- Starting commit: `bc4a7d2`
- Ending source commit: `74c5f48`

## Goal

Prove the approved, checksum-pinned 2025 workbook can be staged losslessly and
committed into a canonical local league through the production database
boundaries, without writing historical league data to hosted Supabase.

## Starting context

Session 0004 deployed the competition schema, atomic historical commit,
official-order ESPN snapshot layer, and commissioner message-composer
foundation. OpenAI and private ESPN credentials are not configured, so the
first unblocked canonical task is the local historical-import rehearsal.

## Work completed

- [x] Confirm clean, synchronized `main` at `bc4a7d2`.
- [x] Re-read canonical tracking, the project foundation, and the 2025 import
      contract.
- [x] Extract all 533 workbook rows and formulas without modifying the source.
- [x] Stage the 2025 league, season, ten teams, source evidence, and mappings.
- [x] Stage all eighteen financial label mappings and seven approved issues.
- [x] Approve the staged batch through commissioner authorization.
- [x] Commit the exact normalized preview and verify stored reconciliation.
- [x] Verify both the RPC and full operational runner are idempotent.
- [x] Validate locally stored ESPN credentials without logging their values;
      2025 and 2026 league reads both returned HTTP 200 and ten teams.
- [x] Implement the server-only ESPN client and strict official-order
      standings normalizer.
- [x] Add redacted fixtures covering final rank, active playoff seed,
      unavailable preseason order, exact mappings, and a twelve-team season.
- [x] Connect normalized standings to the atomic service-role ingestion RPC.

## Decisions

- Keep this rehearsal local-only. A later explicit release decision is required
  before canonical league history is written to production.
- Treat the workbook as immutable source evidence and the approved normalized
  preview as the only domain commit payload.
- Keep team count season-scoped: preserve ten teams for 2025 and support a
  possible twelve-team future season without changing application constants.

## Verification

- Source workbook checksum: exact manifest match.
- Source evidence: 533 rows across all eight manifest ranges.
- `npm test`: 37 tests passing after adding the row-evidence and ESPN adapter
  contracts.
- First rehearsal: `committed` with exact approved reconciliation.
- Second RPC and no-reset runner: `already_committed`.
- Stored counts: 80 matchups, 160 results, 14 awards, 49 obligations, 43
  payments, 43 allocations, and one external cash event.
- Net team balance: `$40` owed to league.
- Realized league cash: `$240`.
- `npm run lint`: passing.
- `npm run typecheck`: passing.
- `npm run db:lint`: passing with no warnings.
- `npm run db:test`: 255 tests passing.
- `npm run build`: passing.
- `npm run tracking:check`: passing with five session logs.
- GitHub `main`: source checkpoint `74c5f48` synchronized.
- Hosted Supabase: all twelve migrations synchronized; dry-run empty.
- Hosted data/schema changes: none.
- Vercel production: `dpl_CVmy7nrZg8ifz5U4MW9UuUoCYkV4` Ready and aliased
  to `https://www.sweetnapadads.com`.
- Production smoke test: homepage and login returned HTTP 200; unauthenticated
  composer access redirected to login with its safe return path.

## Risks or blockers

- Live AI generation remains blocked by the absent server-only OpenAI key.
- ESPN credentials are available only in git-ignored local environment state;
  production configuration remains absent.

## Exact handoff

Start session 0006 from clean, synchronized `main`. Continue with live OpenAI
generation when its key is configured, or add the protected ESPN
synchronization Route Handler and season-team mapping administration.
Production 2025 history remains a separate explicit release decision.
