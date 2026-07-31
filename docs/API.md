# API

The application prefers Server Components for reads and Route Handlers for
mutations, integrations, and automation.

Planned server boundaries:

- `GET /auth/callback`: exchange a PKCE code or verify an email token hash,
  then redirect only to a validated in-application path
- `POST /api/sync/espn`: protected standings and completed-matchup sync for an
  automation caller or authenticated commissioner
- `POST /api/admin/results`: validated manual-results fallback
- `PATCH /api/admin/espn-mappings`: atomically replace every active team ESPN
  mapping for one season
- `PATCH /api/admin/financial-rules`: atomically replace the enabled payout and
  penalty schedule for one season
- `POST /api/admin/payments`: record a payment or disbursement
- `POST /api/admin/adjustments`: append an audited correction
- `POST /api/admin/seasons`: create and configure a season
- `POST /api/admin/message-drafts`: generate an editable commissioner message
  from authorized, server-assembled league context; this endpoint never sends
  email or SMS

All handlers:

1. authenticate the caller;
2. authorize against league membership and role;
3. validate input at the boundary;
4. call domain and data-access services;
5. return stable error codes without exposing secrets.

### `POST /api/sync/espn`

The JSON body is `{ "season_id": "<uuid>" }`. A browser caller must have an
active commissioner membership for that season's league. Automation supplies
`Authorization: Bearer <SYNC_SECRET>`. An optional `Idempotency-Key` header may
contain 1–200 letters, digits, periods, underscores, colons, or hyphens. When
it is omitted, the integration derives a deterministic key from the raw ESPN
response hash.

The handler resolves league ID, season year, and every active season-team ESPN
mapping from PostgreSQL. It fails before fetching if any active team is
unmapped; the count may be ten, twelve, or any season-configured size. Success
atomically records raw evidence, official standings, and every completed
mapped matchup with two reciprocal results. Future and undecided games remain
absent. Success returns status, season/team/matchup counts, derived award-week
count, and any `pending_tie_weeks` requiring commissioner review. The GitHub
workflow intentionally emits only its smaller operational summary. Stable error codes are
`invalid_request`, `unauthorized`, `forbidden`, `season_not_found`,
`team_mapping_incomplete`, `integration_not_configured`,
`standings_unavailable`, `upstream_failed`, and `ingestion_failed`.

The endpoint accepts JSON only, limits declared bodies to 4 KB, and never
returns provider, cookie, environment, or database error details. Public client
code never receives service-role or ESPN credentials.

### `PATCH /api/admin/espn-mappings`

The JSON body contains `season_id` and a non-empty `mappings` array whose rows
are `{ "season_team_id": "<uuid>", "espn_team_id": <positive integer> }`.
The caller must be an active commissioner. PostgreSQL requires the batch to
cover every active season team exactly once with unique ESPN IDs, clears old
values safely so IDs can be swapped, applies the replacement atomically, and
records one immutable audit batch with actor and timestamp. Stable failures are
`invalid_request`, `unauthorized`, `season_not_found`, `forbidden`,
`mapping_rejected`, and `save_failed`.

### `PATCH /api/admin/financial-rules`

The JSON body contains `season_id` and a complete `rules` array. Each rule has
a stable key, kind, label, integer-cent amount, direction, and an optional
placement rank. The caller must be an active commissioner. The boundary limits
the body to 32 KB, rejects malformed, duplicate, unsafe, or direction-conflicted
rules, requires the canonical weekly high and low rules, and replaces the
enabled schedule in one PostgreSQL transaction. The database records the exact
accepted schedule as an immutable commissioner audit snapshot. Stable failures
are `invalid_request`, `unauthorized`, `season_not_found`, `forbidden`,
`rules_rejected`, and `save_failed`.

The message-draft endpoint uses the caller's Supabase session, requires an
active commissioner membership, resolves league context on the server, and
passes only the selected normalized facts to the model. The OpenAI key remains
a non-public Vercel environment variable. A missing key returns a stable
configuration error without exposing environment details.
