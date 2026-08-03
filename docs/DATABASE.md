# Database design

All primary keys are UUIDs. Mutable rows carry `created_at`, `updated_at`, and
where relevant `created_by`. Money is stored as integer cents. Season-owned
records include `season_id`.

## Identity and league

- `leagues`
- `seasons`
- `season_settings`
- `payout_rules`
- `placement_payout_rules`
- `profiles`
- `league_memberships`

## Teams

- `teams`: durable franchise identity
- `owners`: durable owner identity
- `team_owners`: dated ownership history
- `season_teams`: a team's season-specific name, ESPN mapping, and status

## Competition

- `matchups`
- `weekly_results`
- `standings`
- `playoff_results`
- `weekly_awards`
- `manual_result_batches`: immutable commissioner evidence for a complete week
  ESPN did not supply
- `result_correction_batches`: immutable evidence for accepted-week overlays

Source-owned records carry stable ESPN identifiers and `source_updated_at`.
Manual missing-week results and accepted corrections reference their immutable
audit batches. Existing source facts are never overwritten. Security-invoker
`accepted_matchups`, `accepted_weekly_results`, and `accepted_weekly_awards`
views apply missing-week precedence and latest-correction precedence for member
reads.

## Finance

- `financial_obligations`: amounts assessed or owed, with rule provenance
- `payments`: money actually received or disbursed
- `payment_allocations`: append-only settlement links and allocation reversals
- `financial_adjustments`: audited balance corrections
- `external_cash_events`: cash movements with non-team counterparties

Balances are database views over obligations, payments, and adjustments.
Obligations and payments are distinct immutable events. Stable season-scoped
source keys make rule generation and imports idempotent. Allocation triggers
enforce compatible money directions and prevent a payment or obligation from
being over-allocated. Corrections are appended as allocation reversals or
reasoned financial adjustments; posted rows are never edited or deleted.
Season cash is derived separately from team payments and immutable external
cash events, so league expenses never distort a team's balance.

## Content and operations

- `commissioner_posts`
- `activity_events`
- `media_items`
- `side_bets`
- `espn_team_mappings`
- `espn_sync_runs`
- `espn_raw_payloads`
- `espn_standings_snapshots`
- `espn_standing_entries`
- `sync_issues`

`side_bets` preserves immutable season-scoped party, description, integer-cent
stake, source, and import-batch evidence. A side bet is league activity, not a
financial obligation or payment; settlement requires its own later audited
financial event. Members read side bets through league RLS, commissioners may
insert them, and no authenticated role can update or delete the evidence.

## Migration workflow

The repository uses imperative SQL migrations in `supabase/migrations/` as the
single schema representation. Do not make durable schema changes only through
Supabase Studio.

```bash
npm run db:start
npm run db:reset
npm run db:lint
npm run db:test
```

`db:reset` explicitly targets the local Docker database, rebuilds it from every
migration, and then applies `supabase/seed.sql`. The seed must contain only
synthetic local-development data.

The current seed creates a deterministic development commissioner, league,
2026 season, season settings, franchise and ownership chain, plus a partial
buy-in payment with an allocation and audited adjustment. The commissioner
uses the reserved synthetic email
`dev-commissioner@sweetnapadads.test` and intentionally has no password, so it
cannot be used to sign in. Create login-capable local identities through the
Auth admin API or local Studio when exercising the authentication flow. Fixed
UUIDs make application fixtures and database tests reproducible.

`npm run import:2025:rehearse` temporarily assigns a random runtime password to
that synthetic commissioner after a local reset so the actual authenticated
approval and commit RPCs can be exercised. The password is never printed or
stored. The runner refuses hosted Supabase URLs and is safe to rerun.

When a hosted development project exists, link it deliberately and preview
pending migrations before applying them:

```bash
npx supabase link --project-ref <project-ref>
npx supabase db push --dry-run
npx supabase db push
```

Never run a linked reset against production.

Production is never populated from `supabase/seed.sql`. On 2026-08-02 the
confirmed commissioner identity was attached to the canonical production
league with an active commissioner membership, and a neutral 2026 setup season
was created with zero-dollar financial placeholders. Historical 2025 facts are
loaded only through the checksum-pinned staging, approval, and domain-commit
boundary described in `docs/MIGRATION_2025.md`.

## Current migration baseline

`20260731030000_platform_primitives.sql` establishes:

- a non-exposed `private` schema for database-only helpers;
- `league_member_role`, `membership_status`, and `season_status` enums;
- a safe-integer `nonnegative_money_cents` domain;
- a shared `private.set_updated_at()` trigger function;
- explicit public-schema creation and usage privileges.

`20260731033000_league_platform.sql` establishes:

- profiles synchronized from Supabase Auth identities;
- durable leagues, seasons, and season-scoped settings;
- league memberships with member and commissioner roles;
- integer-cent financial settings and season constraints;
- league-scoped RLS helpers, explicit grants, and policies on every table.

`20260731050000_team_ownership.sql` establishes:

- durable league-scoped franchises and historical owner identities;
- optional owner links to current Auth users without requiring them for
  imported history;
- dated ownership records with one current primary owner per franchise;
- season-specific names, abbreviations, ESPN team IDs, and participation
  status;
- composite foreign keys that prevent cross-league ownership or season links;
- commissioner-only writes, member reads, no authenticated delete grants, and
  RLS on every new table.

`20260731060000_financial_events.sql` establishes:

- distinct obligations, payments, allocations, and audited adjustments;
- positive safe-integer cent amounts with explicit money direction;
- stable season-scoped source keys for idempotent generation and import;
- same-league, same-season, and same-team event relationships;
- allocation caps, compatible settlement directions, and append-only
  allocation reversals;
- immutable posted events enforced by triggers and write privileges;
- commissioner-only creation, league-member visibility, outsider isolation,
  and RLS on every financial table.

`20260731070000_financial_views.sql` establishes:

- obligation allocation, outstanding amount, and reconciliation status;
- payment allocation, unallocated amount, and reconciliation status;
- a canonical team-perspective balance formula over obligations, payments,
  and audited adjustments;
- zero-balance rows for participating season teams without financial events;
- security-invoker views so underlying league RLS remains authoritative.

`20260731080000_historical_import_staging.sql` establishes:

- source-hashed import batches with staged, review, approval, commit, and
  rejection states;
- immutable row-level workbook values and formulas without content
  deduplication;
- explicit team-identifier and financial-event type/subtype mappings;
- structured issues with severity, evidence, and commissioner decisions;
- approval guards for unresolved mappings and blocking findings;
- a security-invoker batch review view;
- commissioner-only staging visibility and mutation under RLS.

`20260731090000_external_cash_events.sql` establishes:

- immutable cash-in and cash-out events for non-team counterparties;
- stable season-scoped source keys and integer-cent amounts;
- nullable dates only for imported historical evidence whose exact date is
  absent from the source;
- member visibility, commissioner creation, outsider isolation, and RLS;
- a security-invoker season cash view combining team and external movements.

`20260731100000_competition_history.sql` establishes:

- season-scoped matchups, reciprocal weekly results, and weekly awards;
- exact decimal scores and explicit regular-season or postseason phases;
- stable source keys for import and future ESPN retry safety;
- financial links from every weekly award to its payout and penalty
  obligations;
- immutable imported competition rows, member reads, commissioner creation,
  and league-scoped RLS.

`20260731110000_historical_import_commit.sql` establishes:

- one canonical normalized preview and reconciliation record per committed
  batch;
- source-reference provenance from each batch to every committed domain row;
- an authenticated commissioner-only `commit_historical_import` RPC;
- one transaction across competition, obligation, payment, allocation, and
  external-cash rows;
- exact collision checks, reciprocal-result validation, financial
  reconciliation, and deterministic record counts;
- retry safety: the same batch and preview hash return `already_committed`,
  while a changed preview is rejected.

`20260731120000_espn_standings_snapshots.sql` establishes:

- idempotent ESPN sync runs with explicit running, succeeded, and failed
  states;
- immutable raw response evidence separated from normalized application data;
- immutable standings snapshots whose entries retain ESPN's official rank,
  source team identifiers, record, points, streak, and raw source fragment;
- a security-invoker current-standings view that selects the latest successful
  snapshot and remains stable while a newer run is incomplete or failed;
- member visibility of normalized facts, commissioner-only raw-payload access,
  and service-role-only synchronization writes under RLS.

`20260731130000_commissioner_message_context.sql` establishes:

- a commissioner-only function that assembles one bounded message-generation
  fact package for a season and week;
- ESPN standings in their official source order, with source and capture
  timestamps;
- normalized weekly matchup results and awards without exposing raw ESPN
  payloads;
- an explicit exclusion of financial context from AI message generation.

`20260802173011_notification_framework.sql` adds immutable league notices,
append-only channel delivery evidence, audience-scoped RLS, and the
commissioner-only idempotent publish boundary. The current product writes only
`in_app` delivered events; email and SMS are modeled but inactive.

`20260731140000_espn_standings_ingest.sql` establishes:

- one service-role-only transaction for a successful standings ingestion;
- strict validation of complete active team mappings, unique ESPN team IDs,
  and contiguous official ranks without locally repairing source order;
- atomic creation of the run, immutable raw payload, normalized snapshot, and
  every standing entry before the run becomes successful;
- exact idempotent retries and rejection of reused keys with changed source
  evidence;
- full rollback when any normalized value or relationship is invalid.

`20260731150000_espn_team_mapping_admin.sql` establishes:

- immutable commissioner mapping-audit batches with actor and timestamp;
- commissioner-only visibility and inserts under RLS;
- one atomic full-season mapping replacement function;
- exact active-team coverage with unique positive ESPN identifiers;
- safe identifier swaps by clearing and replacing mappings in one transaction.

`20260731160000_espn_matchup_ingest.sql` establishes:

- raw-run provenance on source-owned ESPN matchups;
- service-role-only validation and upsert of completed matchups and exactly two
  reciprocal results;
- dynamic regular-season/postseason phase supplied by the validated adapter;
- score/outcome consistency, active ESPN mapping checks, and stable source-key
  conflict protection;
- one wrapper transaction that rolls standings, raw evidence, matchups, and
  results back together when any normalized record fails.

`20260731170000_weekly_award_derivation.sql` establishes:

- a season-scoped `commissioner_review` tie policy;
- service-role-only derivation after every active team has one accepted
  regular-season result;
- weekly high/low selection from normalized scores without application math;
- immutable payout and penalty obligations using configured integer-cent
  season amounts and deterministic source keys;
- automatic processing of complete unique-score weeks while incomplete weeks
  wait and tied weeks return as pending review.

`20260731180000_season_financial_rules.sql` establishes:

- one canonical season schedule for weekly awards, placement payouts, season
  awards, and penalties, with positive integer-cent amounts and stable keys;
- database-enforced payout/penalty directions and unique enabled placement
  ranks;
- member-readable rules, commissioner-readable immutable change snapshots,
  and no direct authenticated writes under RLS;
- one commissioner-only atomic replacement function that validates the entire
  enabled schedule and records actor, timestamp, and exact accepted JSON;
- required weekly high/low rules and a compatibility projection back to the
  legacy `season_settings` columns used by the current weekly derivation.

Public self-registration is disabled in `supabase/config.toml`. Authentication
identities will be created through commissioner-controlled invitation or
administrative workflows.

Email authentication remains enabled so invited identities can request a
magic link. Global signup is disabled, and the application also passes
`shouldCreateUser: false`, so the public login form cannot create identities.

The local project is linked to hosted Supabase project
`cleyfpzxckjtmsoesgby`. Always run a linked migration dry-run and complete the
local database suite before applying a migration remotely.
