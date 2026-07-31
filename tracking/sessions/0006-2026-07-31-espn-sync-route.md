# Session 0006 — Protected ESPN synchronization route

- Date: 2026-07-31
- Status: complete — published and deployed
- Branch: `main`
- Starting commit: `ab66028`
- Ending source commit: `401efe0`

## Goal

Add the protected server boundary that resolves season data and mappings,
fetches private ESPN standings, and records one atomic official-order snapshot
without exposing credentials or enabling production synchronization early.

## Starting context

Session 0005 published the server-only ESPN client, strict standings
normalizer, redacted fixtures, dynamic team-count coverage, and atomic
ingestion adapter. Local ESPN credentials are valid; production ESPN and sync
secrets remain intentionally absent.

## Work completed

- [x] Confirm clean, synchronized `main` at `ab66028`.
- [x] Re-read the project foundation, canonical tracking, ESPN contract, API
      contract, and complete bundled Next.js 16 Route Handler guide.
- [x] Add constant-time bearer-secret and strict request validation helpers.
- [x] Implement `POST /api/sync/espn` for commissioner sessions and automation.
- [x] Resolve season identity and every active team mapping from PostgreSQL.
- [x] Pass ESPN responses and optional caller idempotency keys through the
      atomic standings ingestion function.
- [x] Contain configuration, upstream, normalization, and persistence failures
      behind stable response codes.
- [x] Add Route Handler and security coverage, including a twelve-team season.
- [x] Add an atomic full-season mapping RPC and immutable commissioner audit
      batches under RLS.
- [x] Verify safe ESPN ID swaps, exact active-team coverage, uniqueness,
      commissioner authorization, and audit visibility with pgTAP.
- [x] Add the authenticated mapping API with stable errors and twelve-team
      request coverage.
- [x] Build the responsive commissioner control room for mappings, manual sync,
      and recent run status.
- [x] Add commissioner navigation from the dashboard.
- [x] Add a manual-only GitHub Actions workflow for protected production sync.
- [x] Keep ESPN credentials in Vercel while GitHub references only `SITE_URL`
      and the rotating `SYNC_SECRET`.
- [x] Preserve evidence-derived idempotency by omitting caller run identifiers.
- [x] Document production activation, verification, failures, secret rotation,
      and the separate scheduling gate.
- [x] Replace the authenticated placeholder with a responsive member standings
      dashboard sourced from `current_espn_standings` through RLS.
- [x] Preserve ESPN official rank and expose snapshot capture time, scoring
      period, record, points, and streak without recalculation.
- [x] Validate the live 2025 ESPN matchup structure with redacted aggregate
      output and add a committed privacy-safe fixture.
- [x] Normalize completed matchups, ties, reciprocal results, future-game
      exclusion, and season-specific playoff boundaries.
- [x] Add raw-run provenance and an atomic wrapper for standings, matchups, and
      weekly results with idempotent source-owned updates.
- [x] Add season-scoped `commissioner_review` tie policy and automatic
      unique-score weekly award derivation.
- [x] Generate configured high-score payout and low-score penalty obligations
      as immutable events with stable rule source keys.
- [x] Surface pending tied weeks in the protected sync response and
      commissioner control-room result.
- [x] Record ADR 0006: every payout and penalty schedule is season
      configuration and no monetary rule is an application constant.
- [x] Add the canonical season financial-rule schedule for weekly, placement,
      season-award, and penalty categories.
- [x] Add commissioner-only atomic schedule replacement with immutable actor,
      timestamp, and exact-JSON audit evidence.
- [x] Build and visually verify the responsive commissioner rule editor at
      desktop and 390px widths.
- [x] Build the authenticated member results and weekly honors route over
      existing RLS-protected normalized competition tables.
- [x] Add deterministic reciprocal-matchup grouping, exact score formatting,
      stored-award presentation, and honest incomplete/tied states.
- [x] Verify populated historical season/week navigation and desktop/390px
      responsive layouts against the locally rehearsed 2025 record.

## Decisions

- Keep synchronization disabled by configuration until server-only production
  ESPN credentials and an automation secret are deliberately supplied.
- Resolve league, season year, and every active ESPN team mapping from database
  data; never assume ten teams.
- Accept JSON only so a cross-site browser form cannot trigger a session-based
  synchronization mutation.
- Keep an optional caller idempotency key separate from the immutable ESPN
  response-hash source key.
- Replace mapping rows as one audited batch; never issue independent UI row
  updates that can leave a partial or uniqueness-conflicted season.
- Keep GitHub synchronization manual-only until production configuration,
  season policy, and scheduling are explicitly reviewed.

## Verification

- `npm run lint`: passing.
- `npm run typecheck`: passing.
- `npm test`: 90 tests passing.
- `npm run build`: passing with both ESPN APIs and the commissioner control
  room as dynamic routes.
- `npm run db:reset`: passing through all sixteen migrations and seed data.
- `npm run db:lint`: passing with no warnings.
- `npm run db:test`: 329 tests passing.
- `npm run tracking:check`: passing with six session logs.
- Live local browser: magic-link commissioner access and audited mapping save
  passing; disabled sync reports configuration guidance without private detail.
- Responsive browser: 390px document viewport has no horizontal overflow.
- ESPN workflow YAML parses successfully and its contract tests verify
  manual-only execution, least privilege, indirect secrets, evidence-derived
  idempotency, redacted output, and runbook gates.
- Member dashboard browser: authenticated desktop and 390px layouts render the
  current season and explicit no-snapshot state correctly.
- Live ESPN matchup contract: 2025 period counts, completed winners, and
  season-specific playoff boundary verified through redacted aggregates.
- Atomic competition rollback: an invalid matchup leaves no new run or
  standings snapshot.
- Weekly awards: configured amounts and directions, complete-team gates,
  exact retries, deterministic source evidence, and tied-week rollback pass.
- Financial rules: strict parsing, Route Handler authorization, five database
  rule kinds, atomic commissioner replacement, legacy weekly projection,
  immutable audit evidence, and outsider denial pass.
- Season-rule editor: authenticated desktop and 390px responsive browser review
  pass without horizontal overflow.
- Member results: reciprocal scorecards, winner-first presentation, exact
  hundredths, stored honors, pending postseason state, and responsive populated
  2025 browser review pass.
- GitHub `main`: source checkpoint `401efe0` synchronized.
- Hosted Supabase: all sixteen migrations through `20260731180000` synchronized;
  post-apply dry-run empty. No hosted 2025 history was imported.
- Vercel production: `dpl_koVUVkhxKmGmqwoUNHRC45zXriJ7` Ready and aliased to
  `https://www.sweetnapadads.com`.
- Production smoke test: apex and `www` homepages and login return HTTP 200;
  unauthenticated results access redirects to login with a safe return path.

## Risks or blockers

- Production ESPN credentials and the synchronization secret are absent by
  design.

## Exact handoff

Start session 0007 from clean, synchronized `main`. Build member financial
transparency and team-balance views over the canonical security-invoker read
models. Production ESPN activation, SMTP, scheduling, and hosted 2025 history
remain separate explicit decisions.
