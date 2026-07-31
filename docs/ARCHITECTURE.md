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
0005](adr/0005-espn-standings-and-ai-message-context.md).
