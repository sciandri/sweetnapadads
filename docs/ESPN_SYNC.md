# ESPN synchronization

## Workflow

1. Create a sync run for season and scoring period.
2. Fetch the private ESPN league endpoint using server-only cookies.
3. Persist the raw response and response metadata.
4. Validate league identity, team mappings, matchup count, and score state.
5. Normalize teams, matchups, and weekly results.
6. Preserve ESPN's official standings order in an immutable snapshot and
   derive awards from normalized results and season rules.
7. Generate finance obligations from configured rules.
8. Record activity events and final run status.

Successful standings writes cross the database through
`record_espn_standings_snapshot`. The service-role-only function validates that
the normalized entries exactly cover active mapped season teams, that ranks
are unique and contiguous as ESPN supplied them, and that source identifiers
match their stored mappings. It then records the run, raw response, snapshot,
and entries in one transaction. Any invalid entry rolls back the entire write.

## Idempotency

Each run uses a caller-supplied idempotency key unique within its season and
sync kind; the scoring period and source revision remain stored run evidence.
Normalized rows use ESPN source identifiers. Generated awards and obligations
use deterministic source keys. An exact retry resolves to the existing run and
does not duplicate downstream records.

An exact retry of `record_espn_standings_snapshot` returns the original run and
snapshot identifiers. Reusing the same key with a different payload hash,
source revision, capture time, league ID, or source key fails closed.

## Failure behavior

Validation failures create actionable `sync_issues` and leave prior accepted
data intact. Raw responses are retained even for failed runs. Commissioners
can resolve mappings and retry. Manual entry passes through the same validation
and derivation services with `source = manual`.

Cookies are environment secrets and never logged or stored in payload tables.

## Standings authority

ESPN is the canonical authority for standings order. The application stores
ESPN's reported rank, record, points, streak, playoff position, and source team
identifier exactly as received. It never reorders teams from locally computed
records.

Every normalized standings snapshot references its immutable raw ESPN payload
and records the successful sync run and capture time. Reads use the latest
successful snapshot and expose its `captured_at` value so stale data is visible
instead of silently recalculated. If ESPN is unavailable, the prior snapshot
remains authoritative until a newer successful sync replaces it.

The commissioner message generator receives only normalized, authorized facts
from that latest snapshot. The model never receives ESPN cookies or raw private
payloads and cannot query ESPN directly.
