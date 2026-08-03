# ESPN synchronization

## Workflow

1. Create a sync run for season and scoring period.
2. Fetch the private ESPN league endpoint using server-only cookies.
3. Persist the raw response and response metadata.
4. Validate league identity, team mappings, matchup count, and score state.
5. Normalize teams, matchups, and weekly results.
6. Preserve ESPN's official standings order in an immutable snapshot and
   derive unique-score awards from complete normalized results and configured
   season rules.
7. Generate finance obligations from configured rules.
8. Record activity events and final run status.

The server adapter requests ESPN's matchup, matchup-score, and scoreboard views
with the standings response. Completed matchups are accepted only when ESPN
reports `HOME`, `AWAY`, or `TIE`; future and `UNDECIDED` rows remain absent.
Regular-season versus postseason phase is derived from ESPN's season-specific
`matchupPeriodCount`, not an application week constant. Each accepted matchup
produces exactly two mapped, reciprocal score/result rows.

After competition ingestion, complete regular-season weeks derive their weekly
high and low awards plus separate immutable obligations. Amounts come only from
season configuration. Incomplete weeks wait; an exact high or low score tie is
reported under the `commissioner_review` policy and creates no financial event.

The server-only adapter in `lib/integrations/espn/` reads the private-league
credentials from environment state and requests ESPN's settings, teams, and
standings views. It hashes the exact raw response text before persistence. For
a completed season, the adapter uses ESPN's positive `rankCalculatedFinal`;
for an active season, it uses the positive `playoffSeed`. A preseason response
whose rank fields are still zero is rejected as `standings_unavailable`
instead of assigning a local order.

Successful standings writes cross the database through
`record_espn_standings_snapshot`. The service-role-only function validates that
the normalized entries exactly cover active mapped season teams, that ranks
are unique and contiguous as ESPN supplied them, and that source identifiers
match their stored mappings. It then records the run, raw response, snapshot,
and entries in one transaction. Any invalid entry rolls back the entire write.

`POST /api/sync/espn` is the protected orchestration boundary. It accepts an
authenticated commissioner session or a constant-time checked `SYNC_SECRET`
bearer credential, resolves the requested season and all active mappings from
PostgreSQL, fetches ESPN only after authorization and mapping validation, and
passes the result to the atomic ingestion function. The endpoint exists in the
codebase but remains operationally disabled until production ESPN
credentials and `SYNC_SECRET` are deliberately configured.

Commissioners manage mappings and manual runs from
`/dashboard/admin/espn`. Saving replaces the complete active-team mapping set
through one audited database transaction; synchronization remains unavailable
when a mapping is blank or duplicated. The screen also shows recent immutable
run evidence without exposing raw private payloads.

GitHub automation supports `workflow_dispatch` and the bounded in-season
Tuesday schedule documented in the runbook.
It validates the season UUID, uses the protected production environment,
prevents concurrent runs for the same season, and relies on the raw response
hash for retry-safe idempotency. A cron trigger is intentionally absent until
the activation and scheduling decisions in the production runbook are complete.

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
can resolve mappings and retry.

If ESPN cannot supply any accepted result for a complete week, a commissioner
can use `/dashboard/admin/results`. The manual boundary validates exact active
team coverage, records an immutable evidence batch with `source = manual`,
derives reciprocal results, and runs the same configured weekly award logic.
It refuses any week that already has an accepted matchup. Correction mode
appends a commissioner evidence batch, selects it through accepted-result
views, and reconciles displaced award obligations with immutable adjustments.

Cookies are environment secrets and never logged or stored in payload tables.

## Standings authority

ESPN is the canonical authority for standings order. The application stores
ESPN's reported rank, record, points, streak, playoff position, and source team
identifier exactly as received. It never reorders teams from locally computed
records.

Team count is season data, not an application constant. The canonical 2025
history retains ten teams, while a later season may map twelve or another
configured count. Synchronization requires the ESPN response to exactly cover
that season's active mapped teams before a snapshot can become current.

Every normalized standings snapshot references its immutable raw ESPN payload
and records the successful sync run and capture time. Reads use the latest
successful snapshot and expose its `captured_at` value so stale data is visible
instead of silently recalculated. If ESPN is unavailable, the prior snapshot
remains authoritative until a newer successful sync replaces it.

The commissioner message generator receives only normalized, authorized facts
from that latest snapshot. The model never receives ESPN cookies or raw private
payloads and cannot query ESPN directly.

Member-readable normalized source evidence is deliberately minimal: ESPN team
ID, the official rank fields, points, and overall record. Team names and owner
identifiers remain only in the commissioner-restricted raw payload rather than
being copied into a member-readable standings entry.
