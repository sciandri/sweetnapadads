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
- `payment_allocations`: optional settlement links
- `ledger_entries`: immutable accounting events and adjustments

Balances are database views over obligations, payments, and adjustments.

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

Public self-registration is disabled in `supabase/config.toml`. Authentication
identities will be created through commissioner-controlled invitation or
administrative workflows.

The local project is linked to hosted Supabase project
`cleyfpzxckjtmsoesgby`. Always run a linked migration dry-run and complete the
local database suite before applying a migration remotely.
