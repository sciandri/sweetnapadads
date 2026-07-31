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

Source-owned records carry stable ESPN identifiers and `source_updated_at`.
Manual overrides are separate audited records rather than overwritten source
facts.

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
- `espn_sync_payloads`
- `sync_issues`

Detailed SQL and RLS policies will be introduced through numbered migrations
in Phase 1.

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

When a hosted development project exists, link it deliberately and preview
pending migrations before applying them:

```bash
npx supabase link --project-ref <project-ref>
npx supabase db push --dry-run
npx supabase db push
```

Never run a linked reset against production.

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

Public self-registration is disabled in `supabase/config.toml`. Authentication
identities will be created through commissioner-controlled invitation or
administrative workflows.

Email authentication remains enabled so invited identities can request a
magic link. Global signup is disabled, and the application also passes
`shouldCreateUser: false`, so the public login form cannot create identities.

The local project is linked to hosted Supabase project
`cleyfpzxckjtmsoesgby`. Always run a linked migration dry-run and complete the
local database suite before applying a migration remotely.
