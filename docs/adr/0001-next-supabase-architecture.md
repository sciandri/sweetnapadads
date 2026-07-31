# ADR 0001: Next.js and Supabase architecture

- Status: Accepted
- Date: 2026-07-30

## Decision

Use Next.js App Router on Vercel for the web and server request layer, with
Supabase PostgreSQL, Auth, Storage, and Row Level Security as the data
platform. Use GitHub Actions for scheduled synchronization.

## Why

The architecture fits the league's small scale and free-tier goal while
keeping authentication, relational data, policy enforcement, and deployment
operationally simple. PostgreSQL provides the right home for auditable
financial derivations and constraints.

## Consequences

Authorization must be designed in RLS. Server-only operations require careful
credential separation. Free-tier pausing and scheduler limitations need
operational monitoring.
