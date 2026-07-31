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

## Security

- No public self-registration.
- Member and commissioner roles are season-aware.
- RLS is enabled on every user-accessible table.
- Service-role credentials and ESPN cookies are server-only.
- Supabase SSR sessions use cookies refreshed by the root Next.js Proxy.
- Identity checks use verified Auth claims; authorization remains in RLS.
- Protected automation requires a rotating shared secret.
- Financial corrections append reversing or adjustment entries.

See [ADR 0001](adr/0001-next-supabase-architecture.md) and
[ADR 0002](adr/0002-event-based-finance.md).
