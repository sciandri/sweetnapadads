# Current project state

- Last updated: 2026-08-03
- Session: 0009
- Session status: paused — source published; Vercel authentication blocked
- Branch: `main`
- Phase: Phase 5 — Operations
- Checkpoint: source commit `e4de3c4` published and Supabase synchronized;
  production deployment blocked by the active Vercel account

## Current outcome

Phase 0 is complete and published. The repository now has a pinned Supabase
CLI, reproducible local Docker configuration, a tested platform-primitives
migration, database linting, pgTAP coverage, CI database verification, and an
authenticated project-scoped Supabase MCP connection for Codex. Leagues,
seasons, settings, profiles, memberships, and their RLS policies are now
implemented and tested locally. Request-scoped Supabase browser, server,
service-role, and session-refresh clients are in place for Next.js 16. All
twenty-one reviewed migrations are applied to hosted Supabase. Production Auth
uses `https://sweetnapadads.com` with the exact callback allowlist, Vercel has
the canonical `SITE_URL`, and source commit `8bdeeef` is live at
`https://www.sweetnapadads.com`.
Production custom SMTP now uses Resend on the dedicated Auth subdomain. The
first real commissioner invitation was accepted, the confirmed identity has an
active commissioner membership in the canonical production league, and a
neutral 2026 setup season now provides valid navigation context without
inventing teams or financial rules. The Resend credential must be rotated
before inviting additional members because it appeared in an operator-only
verification transcript.
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
The checksum-pinned imported preview contains all 160 results, 14 derived
awards, 49 obligations, 43 payments, and 43 deterministic allocations without
committing history to domain tables. It reconciles to a `$40` net team balance
and `$240` realized league cash balance. A separate immutable external-cash
event model now accounts for the `$700` draft-party expense without assigning
it to a team. The commissioner later confirmed the actual 2025 closing state
was zero for the league and every team; append-only corrections now settle the
remaining `$240` cash and Los Pollos Hermanos II's `$40` balance without
rewriting imported evidence. Direct workbook review confirms all ten `Team
Balance` outputs are zero but `Net Cash (Realized)` is `$240`; the cash
correction is therefore a commissioner-supplied real-world fact rather than a
workbook-derived value. All 28 incoming team payments totaling `$2,710` are
present in production.
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
The canonical 2025 workbook is now preserved in production as 533 row-level source records
with cached values, formulas, and per-row hashes. A local-only operational
runner stages the 2025 season, ten teams, eighteen financial label mappings,
and all seven approved issues, then exercises the real commissioner approval
and domain commit boundaries. It produced and reconciled 80 matchups, 160
results, 14 awards, 49 obligations, 43 payments, 43 allocations, and one
external cash event. Both the RPC retry and a second full runner invocation
returned `already_committed` without duplicates. The explicitly approved
hosted commit now matches those counts and reconciliation totals and preserves
390 domain provenance links.
The server-only ESPN adapter now validates the observed 2025 and 2026 response
shape, preserves ESPN's completed-season final rank or active-season playoff
seed, rejects unavailable preseason order, requires exact season-team mappings
of any configured size, minimizes member-readable source evidence, hashes the
raw response, and submits one atomic ingestion call. Redacted fixtures include
an explicit twelve-team season contract.
Source checkpoint `e4de3c4` is published to GitHub `main`. Hosted Supabase is
synchronized through all twenty-one migrations ending at `20260802183000`;
the post-apply dry-run is empty. The canonical 2025 dataset is committed and
reconciled in production, and the spreadsheet's two side bets are normalized
as immutable member activity. Vercel production deployment
`dpl_5ZmJ2YT327evXjcxfsrLzxx9VtiV` is Ready and aliased to the custom domain.
The protected `POST /api/sync/espn` Route Handler now authorizes an active
commissioner session or constant-time checked automation bearer secret,
validates JSON and idempotency input, resolves every active season mapping
dynamically, fetches private ESPN standings server-side, and records them
through the existing atomic ingestion boundary. Stable responses redact all
provider, credential, and database details. Production execution remains
disabled because ESPN credentials and `SYNC_SECRET` are intentionally absent.
Commissioners now have a responsive ESPN control room at
`/dashboard/admin/espn`. It loads every active team for the selected season,
saves one complete mapping batch through a commissioner-only atomic RPC,
records immutable actor/timestamp evidence, triggers the protected sync route,
and shows recent runs. The screen supports a dynamic team count and passed a
real local magic-link/RLS save plus a 390px no-overflow browser check.

The production ESPN Actions workflow is now defined as manual-only and
disabled by missing environment configuration. It validates the canonical
season UUID, uses least-privilege permissions and per-season concurrency,
references only the GitHub `SYNC_SECRET` and `SITE_URL` configuration, derives
idempotency from raw ESPN evidence, and emits a redacted summary. The runbook
covers activation, manual verification, failures, secret rotation, and the
separate decision required before adding any cron schedule.

The authenticated member dashboard now reads the latest successful standings
snapshot through RLS, selects the active or latest configured season, preserves
ESPN's stored official rank, and displays team labels, record, points for,
points against, streak, scoring period, and the Pacific capture time. Its
responsive card-to-table layout and explicit no-snapshot state were verified
in the authenticated browser at desktop and 390px widths.

The ESPN adapter now consumes matchup, matchup-score, and scoreboard views from
the same private response. Live 2025 shape validation confirmed 80 matchups
across ten teams without logging names, owners, league IDs, cookies, or raw
payloads. Completed ESPN matchups normalize into two reciprocal results; future
and undecided games are excluded, and postseason phase comes from ESPN's
season-specific matchup-period setting. A new service-role wrapper records raw
evidence, official standings, matchups, and results in one transaction, with
stable upserts for score corrections and complete rollback on any invalid row.

Complete regular-season weeks now derive weekly high/low awards automatically
from accepted scores. The payout and penalty amounts come from integer-cent
season configuration, produce separate immutable obligations, and use stable
rule source keys. Incomplete weeks wait. The season-scoped tie policy is
`commissioner_review`: tied extrema create no award or financial row and the
sync response identifies the pending weeks in the commissioner control room.
The commissioner reaffirmed that every payout and penalty category—including
placement and season awards—must be configured as season data, never coded as
a fallback amount; ADR 0006 records that rule.
The canonical `season_financial_rules` schedule now represents weekly awards,
placement payouts, season awards, and general penalties with stable keys and
integer cents. Commissioners replace the complete enabled schedule through one
authorization-checked PostgreSQL transaction. Direct authenticated writes are
unavailable, and every accepted version preserves its actor, timestamp, and
exact JSON as immutable audit evidence. The required weekly rules project into
the legacy settings columns used by current weekly derivation, so those columns
are compatibility state rather than a second configuration surface.
Commissioners can manage the schedule at
`/dashboard/admin/season-rules`. The responsive editor enforces positive dollar
inputs, unique stable keys and placement ranks, makes configuration distinct
from financial events, and passed authenticated desktop and 390px browser
review.
Members can now browse accepted competition history at `/dashboard/results`.
The server-rendered route authorizes an active league membership, validates the
requested season against that league, and reads matchups, reciprocal results,
weekly awards, and season-team labels through RLS. Its deterministic view model
groups each matchup once, preserves stored win/loss/tie outcomes and score
hundredths, and attaches only already-derived awards. Missing honors remain
explicitly pending rather than being inferred from visible scores. The 2025
rehearsal supplied a populated visual contract: season/week selection, Week 14
honors, postseason pending state, five-matchup grids, and 390px mobile layout
all passed.
The weekly honor cards now join their immutable rule obligations and show the
configured league-to-winner payout and low-scorer-to-league penalty beside the
stored high/low score. The browser never recomputes an amount. A deterministic
authenticated Playwright fixture now submits an ESPN-style accepted week
through the real database derivation function and verifies outcomes, honors,
financial directions, exact configured amounts, and mobile layout.
Members can now inspect the league ledger at `/dashboard/finances`. The route
reads the four canonical security-invoker finance views plus immutable event
descriptions through RLS. It keeps actual cash separate from obligations,
summarizes every team-perspective balance, exposes all six components for the
selected team, and joins obligations and payments to their stored reconciliation
status without recalculating the net. The seeded $140 development balance and
the locally rehearsed imported 2025 record both matched canonical data in
desktop and 390px browser review. Production now additionally reflects the
commissioner-confirmed closing state: `$0` league cash and all ten teams
settled at `$0`.
Members can now browse `/dashboard/teams` and durable franchise detail routes.
The season directory derives its team count and entries from data. Each
franchise record combines dated ownership evidence, season-specific names,
accepted win/loss/tie and point summaries, stored weekly-honor counts, and the
canonical season balance. It explicitly distinguishes those summaries from
ESPN's official standings rank and renders missing historical ownership as
`Not linked`. Seeded ownership plus the ten-team 2025 directory and populated
Napa Kojak record passed desktop and 390px browser review.
Members can now browse `/dashboard/activity` for a season-at-a-glance record.
The route reads accepted matchups, stored weekly honors, obligations, payments,
and audited adjustments through the active member's RLS client. It deliberately
keeps competition ordered by scoring week and finance ordered by event date,
with distinct labels and honest empty states. Seeded finance-only data and the
populated 2025 rehearsal both passed desktop and 390px browser review.
The spreadsheet's two `$20` side bets are also normalized as immutable,
RLS-protected activity with exact parties, description, source row, and import
batch. They remain separate from finance and do not invent outcomes,
settlement, or dates.
Commissioners can now fill a complete week that ESPN did not supply at
`/dashboard/admin/results`. The responsive form derives its pairs from every
active season team, accepts scores to the hundredth and a required reason, and
submits one retry-safe request. PostgreSQL locks the season/week, verifies exact
team coverage, records immutable actor/evidence metadata, derives reciprocal
outcomes, and invokes configured regular-season award and obligation logic.
Direct authenticated competition inserts are revoked. Any week with an
accepted matchup fails closed; correcting existing history is deliberately
separate because its financial effects require audited reconciliation.
Accepted-week correction is now implemented as an append-only overlay. The
original competition and finance evidence remains immutable; accepted-result
views select missing-week evidence ahead of later ESPN rows and the latest
correction ahead of prior accepted rows. A correction recalculates awards and
appends neutralizing adjustments plus replacement obligations when extrema
move or disappear. Exact retries are idempotent, changed evidence fails closed,
and all member competition surfaces plus AI context use the accepted views.

The MVP commissioner administration set is complete: ESPN mapping/sync,
season-configured payouts and penalties, missing/corrected result control,
in-app notice publication, and AI-assisted copy generation. The notification
framework preserves immutable notices and per-member in-app delivery evidence.
It does not send email or SMS.

The message composer now calls a commissioner-only server Route Handler that
reassembles authorized context, sends no financial data, disables OpenAI
response storage, and requires strict output containing exactly three editable
drafts. It defaults to the balanced `gpt-5.6-terra` tier and fails safely as
`generation_not_configured` until a server-only key is supplied.

The ESPN workflow now retains manual dispatch and has a bounded Tuesday
September–January schedule. Structured operational events, a secret-free
health endpoint, and an incident/rollback runbook provide the production
observability baseline. Playwright covers authenticated member and commissioner
critical paths at desktop and 390px widths.

The production security-advisor review identified inherited anonymous execute
privileges on two older security-definer RPCs and the hosted RLS event trigger.
A portable grant-hardening migration now removes those anonymous paths while
retaining only the authenticated/service roles required by the guarded RPCs;
pgTAP verifies the exact privilege matrix.

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
- [x] Add and test the protected ESPN standings Route Handler for commissioner
      sessions and scheduled automation.
- [x] Add and test atomic, audited commissioner ESPN mapping administration.
- [x] Add the responsive commissioner mapping, manual sync, and recent-run
      control room.
- [x] Add and test the manual-only GitHub Actions production sync workflow.
- [x] Add the production activation, verification, failure, rotation, and
      scheduling runbook.
- [x] Replace the authenticated placeholder with the responsive member
      standings dashboard over `current_espn_standings` and RLS.
- [x] Add redacted ESPN matchup fixtures and strict completed-game
      normalization with dynamic regular-season and playoff boundaries.
- [x] Atomically ingest ESPN standings, matchups, and reciprocal weekly results
      with raw-run provenance and idempotent source-owned updates.
- [x] Derive complete unique-score weekly awards and configured immutable
      payout/penalty obligations; surface tied weeks for review.
- [x] Record the architecture rule that every payout and penalty schedule is
      season configuration rather than application code.
- [x] Add the audited canonical financial-rule schedule and commissioner editor
      for weekly, placement, season-award, and penalty categories.
- [x] Add the authenticated member results and weekly honors route with stored
      outcomes, honest pending states, and responsive navigation.
- [x] Publish source checkpoint `401efe0` to GitHub `main`.
- [x] Apply and verify migrations `20260731150000` through
      `20260731180000` on hosted Supabase.
- [x] Deploy and smoke-test Vercel production
      `dpl_koVUVkhxKmGmqwoUNHRC45zXriJ7` and the custom domain.
- [x] Add authenticated member financial transparency with team balances,
      component explanations, immutable events, and reconciliation status.
- [x] Add a dynamic team directory and durable franchise ownership, season,
      competition, honors, and financial history pages.
- [x] Add the season-scoped member activity page with separate competition and
      immutable financial event timelines.
- [x] Publish source checkpoint `7624f5d` to GitHub `main`.
- [x] Verify hosted Supabase remains synchronized through all sixteen
      migrations with an empty dry-run.
- [x] Deploy and smoke-test Vercel production
      `dpl_9UgX2X1eWDmSkBoJCBrTjtE2C7YM` and the custom domain.
- [x] Add the authenticated, audited commissioner fallback for a complete week
      missing from ESPN.
- [x] Validate exact active-team coverage, reciprocal outcomes, immutable
      evidence, configured awards, idempotency, and overwrite refusal.
- [x] Add accepted-week overlays and audited award/obligation reconciliation.
- [x] Move member and AI reads to canonical accepted-result projections.
- [x] Add authenticated desktop/mobile Playwright critical-path coverage.
- [x] Add the protected in-season sync schedule, health endpoint, structured
      operational events, and operations runbook.
- [x] Add immutable in-app notification publication and delivery evidence.
- [x] Implement the live AI generation boundary and three-option composer UI.
- [x] Remove inherited anonymous execution from the historical-import and
      commissioner-message security-definer boundaries.
- [x] Commit and reconcile the canonical 2025 history in hosted Supabase.
- [x] Normalize both spreadsheet side bets as visible immutable activity.
- [x] Expose weekly award and penalty obligations directly beside accepted
      ESPN-derived results and verify the end-to-end member view.

## Next actions

1. Rotate the Resend SMTP credential before inviting another real member.
2. Configure the server-only OpenAI key locally and in Vercel, then run one
   reviewed live three-draft smoke test.
3. Configure `SYNC_SECRET`, ESPN secrets, `SITE_URL`, and `SEASON_ID` in their
   documented Vercel/GitHub scopes before scheduled sync can execute.
4. Replace the neutral 2026 setup data with the real ten- or twelve-team roster,
   complete ESPN mappings, and commissioner-approved payout and penalty rules.

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
  The exact preview is committed and reconciled both locally and in production;
  see `docs/MIGRATION_2025.md`.
- The hosted `sweetnapadads` project exists at
  `https://cleyfpzxckjtmsoesgby.supabase.co`. Codex MCP and CLI access are
  authenticated and the CLI is linked. All twenty-one migration versions
  through `20260802183000` match hosted history, and the dry-run is empty.
- Vercel production has the public Supabase values, canonical `SITE_URL`, and
  a server-only Supabase service-role value. Preview and development
  environments remain intentionally unconfigured to avoid silently sharing
  the production database. The service-role value must only be used from
  reviewed server-side boundaries.
- Authentication routes and provider URLs are published. Custom Resend SMTP,
  the accepted commissioner invitation, active membership, and authenticated
  dashboard access are verified. Rotate the SMTP credential before another
  invitation.
- Docker Desktop must be running for local database commands.
- The seeded commissioner is a relational fixture without a password and
  cannot sign in; create login-capable local users through the Auth admin API
  or local Studio.
- The repository is linked locally to Vercel project
  `prj_qNC8JhIZiZfvqlLPU66PYtlrwn7w` in the `sciandri` scope. Production
  deployment `dpl_5ZmJ2YT327evXjcxfsrLzxx9VtiV` remains the last verified
  Ready release. The current Vercel CLI session resolves to
  `igniteiq-frontend`, which cannot access that project; commit `e4de3c4`
  cannot be deployed until the CLI is authenticated to the owning account or
  team. Do not remove or replace `.vercel/project.json` as a workaround.
- ESPN private-league credentials are configured only in git-ignored local
  environment state and validated for both the 2025 and 2026 ten-team league.
  They and `SYNC_SECRET` are not configured in Vercel and must never be
  committed or logged. The sync route therefore remains configuration-disabled.
- An OpenAI API key has not been provided. The composer UI and prompt boundary
  and generation Route Handler are implemented and tested, but a real provider
  call remains disabled until the key is configured server-side.
- `logo/sweetlookingnapadads.png` is the canonical and only supplied brand
  asset and is integrated through a shared responsive component.

## Verification

- `npm audit`: clean
- `npm run lint`: passing
- `npm run typecheck`: passing
- `npm test`: 127 tests passing across 30 files
- `npm run db:reset`: passing
- `npm run db:lint`: passing with no warnings
- `npm run db:test`: 405 database tests passing across 21 files
- `npm run import:2025:rehearse`: passing twice; second run idempotent
- ESPN credential check: authenticated HTTP 200 for 2025 and 2026; league ID
  and ten-team response verified without logging credential values
- `npm run build`: passing
- Invite-only Auth browser smoke test: passing through local email, callback,
  verified claims, membership RLS, and dashboard
- Hosted migration history: all twenty-one versions through `20260802183000`
  match
- Hosted Auth production config: up to date
- GitHub `main`: source checkpoint `e4de3c4` synchronized
- Supabase production dry-run: no pending migrations, seeds, or roles
- Production 2025 import: 533 raw rows, 80 matchups, 160 results, 14 awards,
  49 obligations, 43 payments, 43 allocations, one external cash event, and
  390 provenance links; the source import's `$240` cash and `$40` net team
  balance remain preserved as evidence
- Production 2025 closing correction: one audited `$40` team adjustment and
  one audited `$240` cash reconciliation; all ten team balances and league cash
  now verify at `$0`
- Spreadsheet side-bet activity: two `$20` records committed with exact source
  descriptions and references
- Vercel production `dpl_5ZmJ2YT327evXjcxfsrLzxx9VtiV`: Ready
- `https://sweetnapadads.com`: HTTP 200 after redirect to
  `https://www.sweetnapadads.com/`
- Existing production `/api/health`: HTTP 200 with `status: ok` after the
  blocked deployment attempt; production remains healthy on the prior release
- `https://sweetnapadads.com/login`: HTTP 200 with the invitation-only login
- Unauthenticated `/dashboard/message-composer`: redirects safely to login
- Unauthenticated `/dashboard/results`: safely redirects to
  `/login?next=/dashboard/results`
- Desktop visual pass: passing
- Responsive visual pass: passing at 320px, 390px, 768px, and 1440px with no
  horizontal overflow
- ESPN control-room browser pass: local magic-link Auth, audited mapping save,
  stable disabled-sync guidance, no console errors, and 390px no-overflow layout
- ESPN workflow contract: manual plus bounded in-season schedule, least
  privilege, indirect secrets, evidence-derived idempotency, redacted output,
  and runbook gates verified
- Member standings browser pass: authenticated desktop and 390px layouts show
  the current season, capture evidence, and honest no-snapshot state
- ESPN matchup contract: redacted live 2025 schedule shape verified; completed,
  tied, future, undecided, mapped, and postseason cases covered
- Atomic competition ingestion: exact retries, raw-run provenance,
  score/outcome validation, and full standings rollback verified
- Weekly award derivation: configured cent amounts, immutable obligation
  directions, exact retries, incomplete-week waiting, and tied-week review
  verified
- Financial-rule configuration: five rule kinds, atomic commissioner saves,
  strict parser/API validation, legacy weekly projections, immutable audit
  snapshots, outsider denial, and desktop/390px browser layouts verified
- Member results and honors: reciprocal grouping, stored result order and
  awards, exact scores, season/week selection, incomplete/tied empty states,
  populated 2025 desktop review, and 390px layout verified
- Member finances: canonical balance status/order, summary grouping, component
  formula, reconciled source events, seeded and rehearsed 2025 totals, desktop
  review, and 390px layout verified
- Team record book: newest-first seasons, reciprocal record/point summaries,
  stored honors, canonical balances, ownership ordering and gaps, ten-team 2025
  directory, populated franchise review, and 390px layout verified
- Member league activity: stored matchups and honors remain distinct from
  date-ordered obligations, payments, and adjustments; seeded and rehearsed
  2025 states pass desktop and 390px layouts
- Manual missing-week fallback: strict request parsing, authenticated
  commissioner RPC, exact team coverage, reciprocal outcomes, configured award
  obligations, immutable audit evidence, idempotency, overwrite refusal, and
  outsider denial verified
- Manual-results route smoke: production build serves `/login` and protects
  `/dashboard/admin/results` with the exact safe return path
- Accepted-result corrections: immutable original evidence, latest overlay,
  manual-over-ESPN precedence, award moves/ties, neutralizing adjustments,
  replacement obligations, canonical balances, retry safety, and RLS verified
- Notification framework: immutable publication and delivery evidence,
  audience RLS, idempotency, and 12-member delivery behavior verified
- AI draft boundary: server-side authorization/context, strict three-option
  output, `store: false`, safe missing-key behavior, and redacted failures
  verified
- Playwright critical paths: 9 passing across desktop and 390px mobile; one
  intentional desktop skip for the mobile-only overflow assertion
- Accepted ESPN week browser contract: reciprocal win/loss results, exact
  scores, automatically derived high/low honors, configured `$25` payout and
  `$10` penalty, and desktop/mobile presentation all passing
- Production member-route smoke test: unauthenticated finance, team-directory,
  and activity requests redirect to login with exact safe return paths

## Latest commit intent

`docs: record blocked Vercel release handoff`

## Pickup instruction

Authenticate Vercel CLI to the account or team that owns project
`prj_qNC8JhIZiZfvqlLPU66PYtlrwn7w`, deploy source commit `e4de3c4` to
production, verify the custom domain and health endpoint, and record the
deployment in this session. Do not invite another member until the Resend
credential has been rotated. After release, begin the real 2026 ten- or
twelve-team roster, ESPN mappings, and commissioner-approved season rules.
