# ESPN synchronization

## Workflow

1. Create a sync run for season and scoring period.
2. Fetch the private ESPN league endpoint using server-only cookies.
3. Persist the raw response and response metadata.
4. Validate league identity, team mappings, matchup count, and score state.
5. Normalize teams, matchups, and weekly results.
6. Derive standings and awards.
7. Generate finance obligations from configured rules.
8. Record activity events and final run status.

## Idempotency

Each run uses a unique `(season_id, scoring_period, source_revision)` identity.
Normalized rows use ESPN source identifiers. Generated awards and obligations
use deterministic source keys. A retry updates source-owned facts and does not
duplicate downstream records.

## Failure behavior

Validation failures create actionable `sync_issues` and leave prior accepted
data intact. Raw responses are retained even for failed runs. Commissioners
can resolve mappings and retry. Manual entry passes through the same validation
and derivation services with `source = manual`.

Cookies are environment secrets and never logged or stored in payload tables.
