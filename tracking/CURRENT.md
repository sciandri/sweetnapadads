# Current project state

- Last updated: 2026-07-31
- Session: 0003
- Session status: complete — published and deployed
- Branch: `main`
- Phase: Phase 2 — League and finance
- Checkpoint: authenticated league and finance foundation deployed

## Current outcome

Phase 0 is complete and published. The repository now has a pinned Supabase
CLI, reproducible local Docker configuration, a tested platform-primitives
migration, database linting, pgTAP coverage, CI database verification, and an
authenticated project-scoped Supabase MCP connection for Codex. Leagues,
seasons, settings, profiles, memberships, and their RLS policies are now
implemented and tested locally. Request-scoped Supabase browser, server,
service-role, and session-refresh clients are in place for Next.js 16. All
seven reviewed migrations are applied to hosted Supabase. Production Auth
uses `https://sweetnapadads.com` with the exact callback allowlist, Vercel has
the canonical `SITE_URL`, and source commit `c25a642` is live at
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
      `dpl_DPkGYFhjWBHhVbgYPt1CT7wJex1j`.

## Next actions

1. Configure production SMTP before inviting real members.
2. Implement the atomic, idempotent domain commit for the approved 2025
   normalized preview.
3. Add the service-role value to server environments only when a reviewed
   server-side feature requires it.
4. Create and smoke-test the first real invited member only after SMTP is
   configured.

## Decisions in force

- Next.js App Router on Vercel with Supabase PostgreSQL/Auth/RLS.
- GitHub Actions triggers the protected ESPN synchronization endpoint.
- Financial state is event-based: obligations and payments are separate.
- Money is represented as safe integer cents.
- Rules are season-scoped data rather than application constants.
- `tracking/CURRENT.md` is the canonical session pickup point.

## Known risks and blockers

- The 2025 workbook discrepancies are resolved in the approved decision queue.
  The normalized preview is reconciled but intentionally not committed to
  domain tables; see `docs/MIGRATION_2025.md`.
- The hosted `sweetnapadads` project exists at
  `https://cleyfpzxckjtmsoesgby.supabase.co`. Codex MCP and CLI access are
  authenticated and the CLI is linked. All seven local migration versions
  match hosted migration history.
- Vercel production has the public Supabase URL and publishable key. Preview
  and development environments remain intentionally unconfigured to avoid
  silently sharing the production database.
- Authentication routes and provider URLs are published. A real invited-member
  smoke test remains pending production SMTP.
- Production SMTP is not configured; do not invite real members until it is.
- Docker Desktop must be running for local database commands.
- The seeded commissioner is a relational fixture without a password and
  cannot sign in; create login-capable local users through the Auth admin API
  or local Studio.
- The repository is linked locally to Vercel project
  `prj_qNC8JhIZiZfvqlLPU66PYtlrwn7w` in the `sciandri` scope. Production
  deployment `dpl_DPkGYFhjWBHhVbgYPt1CT7wJex1j` is Ready.
- ESPN private-league credentials have not been provided and must never be
  committed.
- `logo/sweetlookingnapadads.png` is the canonical and only supplied brand
  asset and is integrated through a shared responsive component.

## Verification

- `npm audit`: clean
- `npm run lint`: passing
- `npm run typecheck`: passing
- `npm test`: 25 tests passing
- `npm run db:reset`: passing
- `npm run db:lint`: passing with no warnings
- `npm run db:test`: 153 database tests passing
- `npm run build`: passing
- Invite-only Auth browser smoke test: passing through local email, callback,
  verified claims, membership RLS, and dashboard
- Hosted migration history: all seven local versions match remote
- Hosted Auth production config: up to date
- GitHub `main`: source commit `c25a642`
- Vercel production `dpl_DPkGYFhjWBHhVbgYPt1CT7wJex1j`: Ready
- `https://sweetnapadads.com`: HTTP 200 after redirect to
  `https://www.sweetnapadads.com/`
- `https://sweetnapadads.com/login`: HTTP 200 with the invitation-only login
- Desktop visual pass: passing
- Responsive visual pass: passing at 320px, 390px, 768px, and 1440px with no
  horizontal overflow

## Latest commit intent

`docs: record authenticated league release`

## Pickup instruction

Start session 0004 from clean, synchronized `main`. Configure production SMTP
before inviting real members; otherwise implement the atomic, idempotent
domain commit for the approved normalized 2025 preview.
