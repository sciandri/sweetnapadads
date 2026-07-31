# Implementation plan

## Phase 0 — Foundation

- [x] Initialize repository
- [x] Scaffold Next.js, TypeScript, Tailwind, linting, and tests
- [x] Establish visual language and landing page
- [x] Document architecture and product boundaries
- [x] Add CI workflow
- [x] Complete clean build and dependency review

## Phase 1 — Platform

- Supabase local configuration
- Initial schema and migrations
- Authentication helpers
- Profiles, memberships, roles, and RLS
- Season configuration

## Phase 2 — League and finance

- Teams, owners, and ownership history
- Obligation/payment ledger
- Balance views and reconciliation invariants
- 2025 staging import with issue review

## Phase 3 — Competition

- ESPN adapter and recorded fixtures
- Mapping and sync run administration
- Matchups, results, standings, awards, and playoffs
- Idempotency and failure recovery tests

## Phase 4 — Application

- Authenticated shell and member dashboard
- Standings, results, awards, finance, team, and history pages
- Commissioner administration

## Phase 5 — Operations

- Scheduled sync workflow
- Observability and production runbooks
- Notifications and generated recaps

Each phase ends at a demonstrable, documented checkpoint.
