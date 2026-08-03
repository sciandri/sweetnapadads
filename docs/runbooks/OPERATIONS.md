# Production operations

## Service checks

- `GET /api/health` is the public liveness check. A healthy deployment returns
  HTTP 200 with `status = ok`; it performs no privileged database query and
  exposes no environment or dependency details.
- `GET /login` confirms the public Auth surface is renderable.
- Protected member routes must redirect an unauthenticated request to `/login`
  with an exact local `next` path.

Configure an external uptime monitor against `/api/health` at five-minute
intervals. Alert after two consecutive failures and resolve only after two
consecutive successes. The commissioner should receive the alert outside the
application so an application outage cannot suppress its own notification.

## Operational evidence

Vercel function logs contain structured JSON events for consequential server
operations. Event fields are deliberately bounded; secrets, authorization
headers, cookies, tokens, raw ESPN payloads, and arbitrary error objects must
never be logged. The ESPN success event records only season ID and aggregate
counts. Unexpected failures record the route and stable HTTP status.

Use these evidence sources together:

1. GitHub Actions run state for scheduled and manual synchronization;
2. Vercel structured function events and request status;
3. `espn_sync_runs` plus immutable raw-payload metadata in Supabase;
4. Supabase Postgres and Auth logs for database or login failures.

## Incident response

1. Preserve the prior successful standings snapshot; never delete evidence to
   make a retry pass.
2. Identify the stable API error code and correlate its timestamp with GitHub,
   Vercel, and Supabase evidence.
3. For upstream or preseason-order failures, wait and retry. For mapping
   failures, correct the complete mapping batch in commissioner controls.
4. For database failures, stop automated retries until migrations, RLS, and
   function grants are verified against the deployed source checkpoint.
5. Record any score correction through Result control so source and financial
   history remain append-only.
6. After recovery, run the protected workflow manually and verify member-facing
   accepted results before closing the incident.

## Release and rollback

Every release follows `docs/DEPLOYMENT.md`. Roll back application source in
Vercel when possible; remediate an applied production migration with a reviewed
forward migration. Never use destructive rollback against accepted league or
financial history.
