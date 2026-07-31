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
