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

- [x] Teams, owners, season teams, and ownership history
- [x] Obligation, payment, allocation, and adjustment events
- [x] Balance views and reconciliation invariants
- [x] 2025 staging import with issue review
- [x] Local canonical 2025 staging, commit, reconciliation, and retry rehearsal

## Phase 3 — Competition

- [x] ESPN standings adapter and recorded fixtures
- [x] Protected commissioner and automation standings endpoint
- [x] Commissioner mapping and sync run administration
- [x] ESPN matchups and reciprocal weekly results
- [x] Unique-score weekly awards and configured rule-backed obligations
- [x] Audited configurable weekly, placement, season-award, and penalty schedule
- [x] Audited complete-week fallback when ESPN supplied no accepted results
- [x] Accepted-week correction overlay and financial reconciliation
- Placement/season award derivation and playoffs
- [x] Idempotency and atomic failure-recovery tests

## Phase 4 — Application

- [x] Authenticated shell and official-order member standings dashboard
- [x] Member results, weekly awards, and linked financial-effects page
- [x] Member financial transparency and team-balance page
- [x] Team directory and durable franchise history pages
- [x] League activity page with distinct competition and finance streams
- Commissioner administration (ESPN mapping and financial rules complete)

## Phase 5 — Operations

- [x] Manual-only protected production sync workflow and activation runbook
- Scheduled sync activation after reviewed production secrets and season policy
- Observability and production runbooks
- Notifications and generated recaps

Each phase ends at a demonstrable, documented checkpoint.
