# Current project state

- Last updated: 2026-07-31
- Session: 0005
- Session status: complete — published and deployed
- Branch: `main`
- Phase: Phase 3 — Competition
- Checkpoint: ESPN adapter and canonical import rehearsal published

## Current outcome

Phase 0 is complete and published. The repository now has a pinned Supabase
CLI, reproducible local Docker configuration, a tested platform-primitives
migration, database linting, pgTAP coverage, CI database verification, and an
authenticated project-scoped Supabase MCP connection for Codex. Leagues,
seasons, settings, profiles, memberships, and their RLS policies are now
implemented and tested locally. Request-scoped Supabase browser, server,
service-role, and session-refresh clients are in place for Next.js 16. All
twelve reviewed migrations are applied to hosted Supabase. Production Auth
uses `https://sweetnapadads.com` with the exact callback allowlist, Vercel has
the canonical `SITE_URL`, and source commit `8bdeeef` is live at
`https://www.sweetnapadads.com`.
The local seed now defines a deterministic synthetic commissioner, development
league, 2026 season, and season-scoped rules.
The application now has passwordless invite-only login, dual-form callback
verification, safe return paths, authenticated league authorization, sign-out,
and member-facing access states.
Phase 2 now has durable franchises, historical owners, dated ownership links,
and season-specific team entries with ESPN IDs, same-league constraints, and
league-scoped RLS.
It also has separate immutable obligations and payments, append-only
allocations and reversals, audited adjustments, stable source keys, allocation
caps, and league-scoped financial RLS.
Canonical security-invoker views now derive team balances and exact obligation
and payment reconciliation without duplicating financial state.
The 2025 workbook is now checksum-pinned and inventoried. Lossless staging,
team and event mappings, structured discrepancy decisions, approval guards,
and commissioner-only import RLS are implemented. No source discrepancy was
accepted until its recommended treatment received commissioner approval.
Every finding now has an evidence-backed decision packet with explicit options
and an accepted recommendation. Financial label mappings use `Type + How` so
weekly, season-high, and placement payouts remain distinct.
The checksum-pinned normalized preview contains all 160 results, 14 derived
awards, 49 obligations, 43 payments, and 43 deterministic allocations without
committing history to domain tables. It reconciles to a `$40` net team balance
and `$240` realized league cash balance. A separate immutable external-cash
event model now accounts for the `$700` draft-party expense without assigning
it to a team.
Competition history now has season-scoped matchups, reciprocal results, linked
weekly awards, stable import source keys, immutable imported rows, and RLS.
An authenticated commissioner can commit one approved normalized preview
atomically across competition and finance. The transaction preserves the
canonical JSON and per-record provenance, recomputes reconciliation, safely
accepts exact retries, rejects changed retries, and rolls back completely on
failure.
ESPN synchronization now has idempotent runs, immutable raw response evidence,
and immutable normalized standings snapshots. The latest successful snapshot
remains current through incomplete or failed runs, and standings retain ESPN's
official ordering rather than recalculating local ranks.
Successful standings ingestion now uses one service-role-only transaction that
validates complete season-team mappings and contiguous ESPN ranks, writes raw
and normalized evidence atomically, accepts exact retries, rejects changed
idempotency reuse, and leaves no partial run on failure.
A commissioner-only database function now assembles a bounded message context
from official standings, selected weekly results, and awards while explicitly
excluding finances and raw private payloads. The responsive dashboard composer
lets commissioners choose facts, tone, length, and notes, inspect exactly what
the model would see, edit final copy, and copy it into the league's existing
group-text thread. There is intentionally no SMS delivery or phone-number
storage. Live OpenAI generation is visibly disabled until a server-only API key
is configured and its Route Handler is reviewed.
The canonical 2025 workbook is now preserved as 533 row-level source records
with cached values, formulas, and per-row hashes. A local-only operational
runner stages the 2025 season, ten teams, eighteen financial label mappings,
and all seven approved issues, then exercises the real commissioner approval
and domain commit boundaries. It produced and reconciled 80 matchups, 160
results, 14 awards, 49 obligations, 43 payments, 43 allocations, and one
external cash event. Both the RPC retry and a second full runner invocation
returned `already_committed` without duplicates. Production history was not
modified.
The server-only ESPN adapter now validates the observed 2025 and 2026 response
shape, preserves ESPN's completed-season final rank or active-season playoff
seed, rejects unavailable preseason order, requires exact season-team mappings
of any configured size, minimizes member-readable source evidence, hashes the
raw response, and submits one atomic ingestion call. Redacted fixtures include
an explicit twelve-team season contract.
Source checkpoint `74c5f48` is published to GitHub `main`. Hosted Supabase
remains synchronized through all twelve migrations with an empty migration
dry-run; no production database data or schema changed. Vercel production
deployment `dpl_CVmy7nrZg8ifz5U4MW9UuUoCYkV4` is Ready on the custom domain.

## In progress

- [x] Initialize and verify the local Supabase stack.
- [x] Add the first platform-primitives migration.
- [x] Document the local database workflow and next schema boundary.
- [x] Authenticate the Supabase CLI and link project
      `cleyfpzxckjtmsoesgby`.
- [x] Preview both pending hosted migrations without applying them.
- [x] Link the repository to the existing Vercel project `sweetnapadads`.
- [x] Implement and test the league platform schema and RLS.
- [x] Implement Supabase SSR browser/server clients and the Next.js Proxy.
- [x] Publish the verified foundation to GitHub.
- [x] Apply and verify both hosted Supabase migrations.
- [x] Configure the public Supabase production environment in Vercel.
- [x] Deploy and verify the production application and custom domain.
- [x] Seed a synthetic local development league and commissioner identity.
- [x] Verify the complete application and local database suite.
- [x] Implement and unit-test invite-only magic-link login.
- [x] Implement PKCE and token-hash callback verification.
- [x] Verify unauthenticated, expired-link, and authorized-member browser paths.
- [x] Configure git-ignored local public Supabase and site URL values.
- [x] Integrate the supplied logo across public, Auth, and member-shell states.
- [x] Model and test teams, owners, ownership history, and season teams.
- [x] Model and test obligations, payments, allocations, reversals, and
      adjustments.
- [x] Add and test team balance, obligation reconciliation, and payment
      reconciliation views.
- [x] Audit and checksum-pin the eight-sheet 2025 workbook.
- [x] Add and test lossless historical staging, mappings, issues, and approval
      gates.
- [x] Add a machine-checked decision queue for all seven workbook findings.
- [x] Record commissioner approval for all seven recommended treatments.
- [x] Generate and reconcile the review-only normalized 2025 preview.
- [x] Model external league cash events and the season cash balance view.
- [x] Publish source commit `c25a642` to GitHub `main`.
- [x] Configure hosted Supabase Auth URLs and Vercel production `SITE_URL`.
- [x] Apply migrations `20260731050000` through `20260731090000`.
- [x] Deploy and verify Vercel production
      `dpl_ENTbaLv63W9QivU7QjFUGKF3XMPY`.
- [x] Add and test matchups, reciprocal weekly results, and linked weekly
      awards.
- [x] Add and test the atomic, idempotent historical domain commit RPC.
- [x] Preserve the canonical committed preview and per-row source provenance.
- [x] Record ESPN's official standings order as the canonical league order.
- [x] Add immutable raw ESPN payloads and normalized standings snapshots.
- [x] Add and test atomic, service-role-only ESPN standings ingestion.
- [x] Add and test the commissioner-only message context boundary.
- [x] Add the mobile-responsive commissioner composer and copy workflow.
- [x] Document that the application does not send SMS or store phone numbers.
- [x] Publish source checkpoint `8bdeeef` to GitHub `main`.
- [x] Apply and verify migrations `20260731100000` through
      `20260731140000` on hosted Supabase.
- [x] Deploy and verify Vercel production
      `dpl_2vcpKeionBYH1ob7s9zfBcKyey8u` and the custom domain.
- [x] Preserve all 533 canonical workbook rows and formulas as hashed evidence.
- [x] Rehearse the canonical 2025 stage, approval, commit, reconciliation, and
      exact retry against local Supabase.
- [x] Validate the live private-league standings response shape for 2025 and
      2026 without logging private values.
- [x] Add the server-only ESPN client, strict standings normalizer, redacted
      fixtures, dynamic team-count coverage, and atomic ingestion adapter.
- [x] Publish source checkpoint `74c5f48` to GitHub `main`.
- [x] Verify hosted Supabase is current with no pending migrations.
- [x] Deploy and smoke-test Vercel production
      `dpl_CVmy7nrZg8ifz5U4MW9UuUoCYkV4` and the custom domain.

## Next actions

1. Configure a server-only OpenAI API key, then implement and test the reviewed
   message-draft Route Handler that returns three editable options.
2. Add a protected ESPN synchronization Route Handler and season-team mapping
   administration before enabling scheduled or production synchronization.
3. Decide when the locally rehearsed canonical 2025 history should be staged
   and committed to hosted Supabase; do not infer production authorization.
4. Configure production SMTP before inviting real members.
5. Create and smoke-test the first real invited member only after SMTP is
   configured.

## Decisions in force

- Next.js App Router on Vercel with Supabase PostgreSQL/Auth/RLS.
- GitHub Actions triggers the protected ESPN synchronization endpoint.
- Financial state is event-based: obligations and payments are separate.
- Money is represented as safe integer cents.
- Rules are season-scoped data rather than application constants.
- Team count is season-scoped; 2025 remains ten teams and future seasons may
  expand to twelve without changing application constants.
- ESPN's official reported standings order is canonical and is never locally
  recalculated.
- AI league messages are commissioner-reviewed copy for the existing group
  thread; the application does not deliver SMS.
- `tracking/CURRENT.md` is the canonical session pickup point.

## Known risks and blockers

- The 2025 workbook discrepancies are resolved in the approved decision queue.
  The exact preview has now been staged, committed, reconciled, and retried
  locally. Production history remains intentionally absent pending a separate
  explicit decision; see `docs/MIGRATION_2025.md`.
- The hosted `sweetnapadads` project exists at
  `https://cleyfpzxckjtmsoesgby.supabase.co`. Codex MCP and CLI access are
  authenticated and the CLI is linked. All twelve migration versions through
  `20260731140000` match hosted history.
- Vercel production has the public Supabase values, canonical `SITE_URL`, and
  a server-only Supabase service-role value. Preview and development
  environments remain intentionally unconfigured to avoid silently sharing
  the production database. The service-role value must only be used from
  reviewed server-side boundaries.
- Authentication routes and provider URLs are published. A real invited-member
  smoke test remains pending production SMTP.
- Production SMTP is not configured; do not invite real members until it is.
- Docker Desktop must be running for local database commands.
- The seeded commissioner is a relational fixture without a password and
  cannot sign in; create login-capable local users through the Auth admin API
  or local Studio.
- The repository is linked locally to Vercel project
  `prj_qNC8JhIZiZfvqlLPU66PYtlrwn7w` in the `sciandri` scope. Production
  deployment `dpl_CVmy7nrZg8ifz5U4MW9UuUoCYkV4` is Ready.
- ESPN private-league credentials are configured only in git-ignored local
  environment state and validated for both the 2025 and 2026 ten-team league.
  They are not configured in Vercel and must never be committed or logged.
- An OpenAI API key has not been provided. The composer UI and prompt boundary
  are implemented, but live generation remains disabled until the key is
  configured server-side and the Route Handler is added and tested.
- `logo/sweetlookingnapadads.png` is the canonical and only supplied brand
  asset and is integrated through a shared responsive component.

## Verification

- `npm audit`: clean
- `npm run lint`: passing
- `npm run typecheck`: passing
- `npm test`: 37 tests passing
- `npm run db:reset`: passing
- `npm run db:lint`: passing with no warnings
- `npm run db:test`: 255 database tests passing
- `npm run import:2025:rehearse`: passing twice; second run idempotent
- ESPN credential check: authenticated HTTP 200 for 2025 and 2026; league ID
  and ten-team response verified without logging credential values
- `npm run build`: passing
- Invite-only Auth browser smoke test: passing through local email, callback,
  verified claims, membership RLS, and dashboard
- Hosted migration history: all twelve versions through `20260731140000` match
- Hosted Auth production config: up to date
- GitHub `main`: source checkpoint `74c5f48` synchronized
- Supabase production dry-run: up to date with no pending migrations
- Vercel production `dpl_CVmy7nrZg8ifz5U4MW9UuUoCYkV4`: Ready
- `https://sweetnapadads.com`: HTTP 200 after redirect to
  `https://www.sweetnapadads.com/`
- `https://sweetnapadads.com/login`: HTTP 200 with the invitation-only login
- Unauthenticated `/dashboard/message-composer`: redirects safely to login
- Desktop visual pass: passing
- Responsive visual pass: passing at 320px, 390px, 768px, and 1440px with no
  horizontal overflow

## Latest commit intent

`docs: record ESPN adapter production release`

## Pickup instruction

Start session 0006 from clean, synchronized `main`. Continue with live OpenAI
generation when its server-only key is available, or add the protected ESPN
synchronization Route Handler and season-team mapping administration.
Production 2025 history still requires an explicit release decision.
