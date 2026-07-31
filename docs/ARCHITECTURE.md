# Architecture

## System shape

The application is a Next.js App Router deployment on Vercel backed by
Supabase PostgreSQL and Auth. Route Handlers own authenticated mutations and
external integrations. Server Components read through a typed data-access
layer. PostgreSQL remains the authority for authorization and financial
derivations.

```text
Browser
  -> Next.js Server Components / Route Handlers
      -> Supabase Auth
      -> PostgreSQL + RLS
      -> ESPN integration
      -> OpenAI message drafting (server-only, pending credentials)
      -> object storage

GitHub Actions
  -> protected sync Route Handler
      -> ESPN
      -> raw payload + normalized records + derived events
```

## Boundaries

- `app/`: routes, layouts, and request boundaries
- `components/`: reusable presentation components
- `lib/domain/`: pure business rules
- `lib/data/`: server-only database access
- `lib/integrations/`: ESPN and other external adapters
- `lib/supabase/`: request-scoped browser, server, admin, and Proxy clients
- `supabase/migrations/`: schema, functions, triggers, and RLS
- `scripts/`: import and operational tooling

UI components do not calculate balances or decide permissions. Domain logic
does not depend on React. Database policies are tested independently.

## Data flow

ESPN responses are written to immutable sync payload records before
normalization. A run validates team mappings and completeness, upserts
source-owned competition rows, then recalculates standings, awards, and
financial obligations in one controlled workflow. Stable source keys and
unique constraints make retries safe.

Manual score entry uses the same normalization and derivation path and records
its origin and actor.

The commissioner message composer reads through one PostgreSQL function that
enforces commissioner membership and returns only normalized, selected league
facts. ESPN's stored rank is passed through unchanged; the application and
model never recalculate standings. The future OpenAI Route Handler will receive
that bounded fact package plus commissioner notes and return editable drafts.
No raw ESPN payload, financial data, phone number, or SMS delivery capability
crosses the generation boundary.

The ESPN fetcher is intentionally separated from database persistence.
After it fetches and validates a response server-side, it submits the raw
evidence and normalized official-order entries to one service-role-only
database function. That function is the atomic boundary: partial snapshots
cannot become current, and an exact retry resolves to the original snapshot.
The adapter in `lib/integrations/espn/` now provides the server-only client,
strict pure normalizer, and service-role ingestion call. Its recorded fixtures
are redacted and contain no private team names, owner identifiers, or cookies.
The Node.js Route Handler at `POST /api/sync/espn` composes those boundaries.
It authenticates before reading season data, authorizes commissioners through
RLS or verifies the automation bearer secret in constant time, and returns
only stable error codes.

GitHub Actions receives only the production application origin and rotating
automation secret, then calls that same Route Handler. ESPN cookies and the
Supabase service-role credential remain exclusively in Vercel's server-only
environment and never enter GitHub Actions. The workflow is manual-only until
the production activation and scheduling gates are reviewed.

Commissioner mapping changes cross
`set_espn_season_team_mappings` rather than issuing row-by-row UI updates. The
function validates exact active-team coverage, temporarily clears old IDs so
swaps cannot violate uniqueness mid-operation, replaces the complete set in one
transaction, and writes an immutable `espn_team_mapping_changes` audit batch.

Completed ESPN matchups cross the same outer competition-snapshot transaction
as raw evidence and standings. The adapter derives phase from ESPN season
settings, excludes undecided games, and supplies two reciprocal results. The
database validates mappings, score/outcome agreement, and stable source
identity before source-owned ESPN rows are inserted or refreshed. Any matchup
failure rolls back the new run, raw payload, and standings snapshot together.

Complete regular-season weeks then pass through database award derivation.
High-score payouts and low-score penalties read integer-cent amounts from the
season configuration and create immutable obligations, never payments.
`season_financial_rules` is the canonical complete schedule for weekly rules,
placement payouts, season awards, and general penalties. Commissioners replace
that enabled schedule through one audited security-definer function; direct
authenticated writes are unavailable. The two legacy weekly amount columns are
maintained only as a compatibility projection for the current weekly derivation
and are not an independent configuration surface. Tied extrema currently follow
the explicit `commissioner_review` policy and produce no financial row.

The authenticated member dashboard reads `current_espn_standings` through the
member's request-scoped Supabase client and RLS. It joins only season-team
display labels, orders by ESPN's stored `official_rank`, and exposes the
snapshot capture time and scoring period so members can see when the table was
last accepted. An absent snapshot produces an explicit empty state rather than
locally derived standings.

The member results route reads `matchups`, `weekly_results`, `weekly_awards`,
and season-team labels through the same request-scoped client and their existing
league RLS. A deterministic presentation model groups reciprocal results into
one matchup, retains stored win/loss/tie outcomes and exact scores, and attaches
only persisted weekly honors. Season and week filters are server-rendered URL
state. The view never infers an award from visible scores; absent awards remain
explicitly pending for incomplete or tied weeks.

Approved historical previews cross a single PostgreSQL transaction boundary.
The database resolves season-team identifiers, validates reciprocal results,
creates competition and financial rows, records per-row provenance, reruns
reconciliation, and only then marks the batch committed. Exact retries are
safe; changed retries fail closed.

## Security

- No public self-registration.
- Member and commissioner roles are season-aware.
- RLS is enabled on every user-accessible table.
- Service-role credentials and ESPN cookies are server-only.
- Supabase SSR sessions use cookies refreshed by the root Next.js Proxy.
- Identity checks use verified Auth claims; authorization remains in RLS.
- Public login is passwordless and invite-only: magic-link requests never
  create users, callbacks accept PKCE codes or verified token hashes, and
  return paths are restricted to this application.
- Authenticated screens verify both claims and active league membership; the
  Proxy refreshes sessions but is not the authorization boundary.
- Protected automation requires a rotating shared secret.
- Financial corrections append reversing or adjustment entries.

See [ADR 0001](adr/0001-next-supabase-architecture.md) and
[ADR 0002](adr/0002-event-based-finance.md), [ADR
0003](adr/0003-external-league-cash-events.md), and [ADR
0004](adr/0004-atomic-historical-domain-commit.md), and [ADR
0005](adr/0005-espn-standings-and-ai-message-context.md), and [ADR
0006](adr/0006-espn-competition-and-configured-awards.md).
