# ESPN standings synchronization runbook

## Current operating mode

The GitHub Actions workflow retains manual dispatch and defines an in-season
Tuesday schedule. The schedule becomes operational only after this source is
published and the protected production environment passes the activation gate
below. Until then, missing `SEASON_ID` or secret configuration fails closed.

## Activation gate

1. Publish and apply every reviewed migration, including
   `20260731150000_espn_team_mapping_admin.sql`.
2. Deploy the protected `POST /api/sync/espn` endpoint and commissioner ESPN
   control room from the same reviewed source checkpoint.
3. Create or select the production season and record its canonical UUID.
4. In `/dashboard/admin/espn`, review every active team and save one unique,
   positive ESPN team ID for each. The count is season data and may be ten,
   twelve, or another configured size.
5. Configure these server-only Vercel Production values:
   `ESPN_LEAGUE_ID`, `ESPN_S2`, `ESPN_SWID`, and `SYNC_SECRET`.
6. Configure the GitHub Actions `production` environment:
   - secret `SYNC_SECRET`, exactly matching the Vercel value;
   - variable `SITE_URL`, exactly `https://sweetnapadads.com`.
   - variable `SEASON_ID`, the canonical active production season UUID.
7. Keep ESPN credentials only in Vercel. GitHub receives the synchronization
   secret but never receives ESPN cookies or the Supabase service-role key.

## Manual production run

1. Open **Actions → ESPN standings sync → Run workflow**.
2. Enter the canonical production season UUID—not the ESPN league ID or year.
3. Start the workflow and wait for the `synchronize` job to succeed.
4. The workflow emits only `{status, season_id, team_count}`. It never prints
   the bearer secret, ESPN cookies, raw ESPN payload, or database details.
5. Open the commissioner ESPN control room and verify:
   - the run appears in **Recent evidence**;
   - the team count matches the reviewed active mappings;
   - the latest successful standings capture time advances when ESPN returned
     new evidence;
   - member-facing order matches ESPN's official order.

The workflow intentionally omits a caller idempotency header so the endpoint
derives its key from the immutable raw ESPN response hash. Automatic HTTP
retries, a GitHub re-run, and a later dispatch of identical source evidence all
resolve to the existing snapshot. A genuinely changed response produces a new
source key and snapshot.

## Stable failure responses

| Error | Meaning | Action |
| --- | --- | --- |
| `unauthorized` | GitHub and Vercel sync secrets do not match | Rotate both values together, then re-run the same workflow run |
| `season_not_found` | UUID is absent or outside the configured production league | Copy the season UUID from commissioner administration |
| `team_mapping_incomplete` | Active mappings do not exactly match the ESPN response | Review every mapping and the season's active team count |
| `integration_not_configured` | A server-only Vercel value is absent | Verify all four production values without printing them |
| `standings_unavailable` | ESPN has not published an official order | Leave the prior snapshot current and retry after ESPN updates |
| `upstream_failed` | ESPN was unavailable or returned unusable data | Preserve the prior snapshot and retry the same run later |
| `ingestion_failed` | Atomic database persistence failed | Inspect Vercel and Supabase logs; do not bypass the RPC |

Any failure leaves the prior successful standings snapshot authoritative. Do
not manually reorder teams, edit raw payloads, or delete failed evidence.

## Secret rotation

1. Generate a new high-entropy value locally without putting it in shell
   history, source control, chat, or logs.
2. Replace `SYNC_SECRET` in Vercel Production.
3. Replace `SYNC_SECRET` in the GitHub `production` environment immediately.
4. Redeploy Vercel so the new value is active.
5. Run one manual synchronization and verify the control room.
6. The old value is invalid as soon as Vercel uses the replacement.

## Scheduled production run

The cron expression `0 16 * 9-12,1 2` runs Tuesdays at 16:00 UTC during
September through January. That is 9:00 a.m. Pacific while daylight saving
time is active and 8:00 a.m. Pacific during standard time. The five-month gate
keeps the workflow dormant during the league offseason; manual dispatch remains
available for recovery and preseason verification.

Scheduled runs read the active canonical UUID from the protected GitHub
`SEASON_ID` variable. Change that variable as part of each new-season release;
never hardcode a UUID into the workflow. A missing or malformed value stops
before any network call. Review the first manual run after every season or
secret rotation before relying on the next scheduled execution.
