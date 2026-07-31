# Project checklist

This checklist is authoritative for execution state. Detailed scope and
sequencing live in `docs/IMPLEMENTATION_PLAN.md`.

## Phase 0 — Foundation

- [x] Initialize Git repository on `main`.
- [x] Scaffold Next.js, React, TypeScript, Tailwind, and ESLint.
- [x] Add Vitest and a deterministic money-formatting test.
- [x] Establish initial visual language and landing page.
- [x] Create core product and engineering documentation.
- [x] Record initial architecture decisions.
- [x] Add GitHub Actions quality workflow.
- [x] Add canonical session tracking and validation.
- [x] Resolve npm security audit findings.
- [x] Complete responsive visual verification.
- [x] Verify GitHub remote and upstream (none configured).
- [x] Run the local “update and track” closeout and create the initial commit.
- [ ] Configure the GitHub `origin` and branch upstream.
- [ ] Push the initial checkpoint to GitHub.

## Phase 1 — Platform

- [ ] Initialize Supabase local development configuration.
- [ ] Define database roles, enums, and shared functions.
- [ ] Create leagues, seasons, and season settings.
- [ ] Create profiles and league memberships.
- [ ] Implement Supabase Auth server/client helpers.
- [ ] Implement and test Row Level Security.
- [ ] Seed a development league and commissioner.

## Phase 2 — League and finance

- [ ] Model teams, owners, season teams, and ownership history.
- [ ] Implement obligations, payments, allocations, and adjustments.
- [ ] Create balance and reconciliation views.
- [ ] Test finance invariants and correction workflows.
- [ ] Build 2025 staging import and mapping.
- [ ] Resolve workbook discrepancies with commissioner decisions.
- [ ] Commit a reconciled 2025 historical import.

## Phase 3 — Competition

- [ ] Implement ESPN client and redacted fixtures.
- [ ] Implement team mappings and sync-run lifecycle.
- [ ] Persist raw ESPN payloads.
- [ ] Normalize matchups and weekly results idempotently.
- [ ] Derive standings and weekly awards.
- [ ] Generate rule-backed financial obligations.
- [ ] Add manual-results fallback.

## Phase 4 — Application

- [ ] Build authenticated application shell.
- [ ] Build member dashboard.
- [ ] Build standings, results, and awards.
- [ ] Build financial transparency and team balances.
- [ ] Build team, history, records, and activity pages.
- [ ] Build commissioner administration.
- [ ] Add Playwright critical-path coverage.

## Phase 5 — Operations

- [ ] Add protected scheduled synchronization workflow.
- [ ] Add production observability and runbooks.
- [ ] Configure Vercel and Supabase production environments.
- [ ] Add notification framework.
- [ ] Add AI-generated recap workflow.
