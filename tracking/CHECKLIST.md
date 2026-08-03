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
- [x] Verify the initial GitHub remote state (none configured at the time).
- [x] Run the local “update and track” closeout and create the initial commit.
- [x] Configure the GitHub `origin` and branch upstream.
- [x] Push the initial checkpoint to GitHub.

## Phase 1 — Platform

- [x] Initialize Supabase local development configuration.
- [x] Define database roles, enums, and shared functions.
- [x] Create leagues, seasons, and season settings.
- [x] Create profiles and league memberships.
- [x] Implement Supabase Auth server/client helpers.
- [x] Build the invite-only magic-link login and callback flow.
- [x] Implement and test Row Level Security.
- [x] Seed a development league and commissioner.

## Phase 2 — League and finance

- [x] Model teams, owners, season teams, and ownership history.
- [x] Implement obligations, payments, allocations, and adjustments.
- [x] Create balance and reconciliation views.
- [x] Test finance invariants and correction workflows.
- [x] Build 2025 staging import and mapping.
- [x] Resolve workbook discrepancies with commissioner decisions.
- [x] Rehearse the complete canonical 2025 import locally and idempotently.
- [x] Commit a reconciled 2025 historical import.
- [x] Normalize all spreadsheet activity, including both undated side bets.

## Phase 3 — Competition

- [x] Implement the server-only ESPN standings client and redacted fixtures.
- [x] Implement season-team mappings and the sync-run lifecycle.
- [x] Persist immutable raw ESPN payload evidence.
- [x] Persist official-order standings snapshots atomically and idempotently.
- [x] Add commissioner-only league context over standings, results, and awards.
- [x] Normalize ESPN's official order into the atomic snapshot RPC.
- [x] Add the protected commissioner and automation standings endpoint.
- [x] Normalize ESPN matchups and weekly results idempotently.
- [x] Derive unique-score weekly awards and report tied weeks for review.
- [x] Generate weekly rule-backed financial obligations from season config.
- [x] Configure every placement, season-award, and penalty schedule as data.
- [x] Add audited manual entry for a complete week missing from ESPN.
- [x] Add correction and financial reconciliation for an accepted week.

## Phase 4 — Application

- [x] Build authenticated application shell.
- [x] Build responsive commissioner ESPN mapping and run controls.
- [x] Build member dashboard with latest official-order ESPN standings.
- [x] Build standings, results, and awards.
- [x] Build financial transparency and team balances.
- [x] Build team, history, and franchise record pages.
- [x] Build league activity page.
- [x] Build commissioner administration for the MVP operational controls.
- [x] Add Playwright critical-path coverage.

## Phase 5 — Operations

- [x] Add protected scheduled synchronization workflow.
- [x] Add manual-only production sync workflow and activation/failure runbook.
- [x] Add production observability and runbooks.
- [x] Configure linked Vercel and Supabase production projects and Auth URLs.
- [x] Add notification framework.
- [x] Add the authorized, copy-only AI recap context and composer foundation.
- [ ] Enable live AI draft generation after server-only key configuration.
