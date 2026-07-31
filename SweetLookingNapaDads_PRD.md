# Sweet Looking Napa Dads

## Complete Product Requirements Document

## \# Product Requirements Document (PRD)

## Project

Sweet Looking Napa Dads Domain: https://sweetnapadads.com

## Vision

Build the permanent home for the fantasy football league. It should
automate operations, preserve league history, provide complete financial
transparency, and be entertaining enough that members say: 'The
commissioner has way too much free time.'

## Objectives

-   Automate ESPN ingestion
-   Automate standings, awards and financial obligations
-   Preserve historical seasons
-   Support configurable rules
-   Support 10 teams in 2025 and 12+ thereafter
-   Require almost no commissioner effort

## Success Metrics

\<5 minutes/week commissioner work, zero duplicate syncs, 100%
reconciliation with spreadsheet, members primarily use this instead of
ESPN for league history and finances.

## Personas

Commissioner, League Member

## Guiding Principles

Configuration over code. Every rule is season-scoped. Enter once, derive
everything. Every financial change is auditable. Raw ESPN payloads are
retained.

## Tech Stack

Next.js App Router, TypeScript, Tailwind, shadcn/ui, Supabase
Postgres/Auth/RLS, Vercel, GitHub Actions.

## Modules

Competition, Finance, Commissioner CMS, Legacy, Media, Admin.

## Season Configuration

All values configurable: team count, buy-in, draft party fee, regular
season weeks, playoff teams, weekly payout, weekly penalty, season-high
bonus (fixed or %), unlimited placement payout rules (fixed or %).

## Database Model

Core entities: leagues, seasons, season_settings, payout_rules,
placement_payout_rules, teams, owners, team_owners, season_teams, users,
matchups, weekly_results, standings, playoff_results, weekly_awards,
ledger_entries, financial_obligations, payments, commissioner_posts,
activity_events, media_items, espn_team_mappings, espn_sync_runs,
espn_sync_payloads, sync_issues.

## Financial Engine

Automatically create weekly payout obligations and penalties from synced
scores. Record actual payments separately. Compute balances from
obligations vs payments. Never hardcode payout percentages.

## Automation

GitHub Actions triggers protected sync endpoint. Sync downloads ESPN
JSON, stores raw payload, validates, upserts, recalculates standings,
awards, obligations, records, activity feed. Idempotent by design.

## Historical Import

Import existing 2025 spreadsheet via staging workflow with preview,
mapping, reconciliation and commit. Imported balances must exactly match
spreadsheet.

## UI Pages

Landing, Login, Dashboard, Standings, Weekly Results, Awards, Financial
Transparency, Team Pages, Record Book, Trophy Cabinet, Activity Feed,
Commissioner Admin, Settings.

## Admin

Create seasons, configure rules, add teams, invite members, map ESPN
teams, trigger sync, manage ledger, publish announcements, upload media.

## Security

Supabase Auth, Row Level Security, commissioner/member roles, service
key only on server.

## Testing

Vitest, Playwright, database/RLS tests, reconciliation tests, sync
tests.

## Build Order

1 Architecture review 2 Schema 3 Seed 4 Auth 5 RLS 6 DAL 7 Admin 8
Member UI 9 Import 10 ESPN Sync 11 Activity Feed 12 Records 13 Testing
14 Deployment.

## Future Roadmap

Golf draft module, push notifications, mobile PWA, AI weekly recap
generation, trade history, waiver analytics.

## Definition of Done

Production-ready code only. No pseudocode. Each phase documented. Wait
for approval between phases.

## Detailed Functional Requirements

### Competition

-   Weekly matchups
-   Live standings after sync
-   Points For/Against
-   Playoff bracket
-   Weekly awards
-   Lifetime records

### Finance

-   Transparent ledger
-   Team balance page
-   League treasury summary
-   Dues tracking
-   Penalties
-   Payouts
-   Audit history

### Automation Philosophy

The commissioner should never manually enter information already
available from ESPN. Manual workflows exist only as fallbacks.

### Branding

Domain: sweetnapadads.com Tone: fun, polished, premium, inside jokes
welcomed.
