# Sweet Looking Napa Dads

> The permanent home of the Sweet Looking Napa Dads Fantasy Football League.

---

# Project Vision

Sweet Looking Napa Dads is a modern web application that replaces our existing Google Sheets–based league management system.

The application is designed specifically for our fantasy football league, but the architecture should be clean enough that it could eventually support additional leagues.

The goal is **not** to build another ESPN clone.

The goal is to automate everything around the league that ESPN doesn't do.

Think of it as:

- League headquarters
- Financial ledger
- Commissioner CMS
- Historical archive
- Record book
- Automation platform
- League museum

The application should make league management effortless while creating a fun experience for league members.

**Desired reaction:**

> "The commissioner has way too much free time."

---

# Core Principles

## Automate Everything

Information should be entered exactly once. ESPN should be the source of truth whenever possible.

Derived automatically:

- Standings
- Weekly winners
- Penalties
- Payouts
- Balances
- Records
- Statistics
- Activity feed

## Nothing Important Is Hardcoded

Every season can configure:

- Buy-in
- Draft fee
- Weekly payouts
- Lowest-score penalties
- Playoff teams
- Season awards
- Podium payouts
- Season length

Configuration belongs in the database.

## Financial Transparency

Maintain an immutable ledger for:

- League dues
- Payouts
- Penalties
- Side bets
- Reimbursements
- Adjustments

Every owner should always know:

- What they owe
- What they are owed
- Why

## Preserve History

Nothing is deleted.

Historical data includes:

- Seasons
- Owners
- Teams
- Scores
- Awards
- Payouts
- Records
- Media

## Fun Matters

This is a hobby project.

Include personality:

- Weekly recaps
- Commissioner announcements
- Trophy cabinet
- Hall of Fame
- Funny awards
- Memes
- Rivalries
- League lore

---

# Existing Source Data

Current Google Sheets workbook:

- Teams
- Weekly Results
- Weekly Awards
- League Ledger
- Team Balance
- League Payouts
- Net Cash
- Bets

Goal #1 is feature parity with the spreadsheet before expanding functionality.

---

# Technology Stack

## Frontend

- Next.js
- TypeScript
- Tailwind CSS
- shadcn/ui

## Backend

- Next.js Route Handlers

## Database

- Supabase PostgreSQL

## Authentication

- Supabase Auth

## Authorization

- PostgreSQL Row Level Security

## Hosting

- Vercel

## Automation

- GitHub Actions

## Testing

- Vitest
- Playwright

---

# Documentation Structure

```
docs/
    README.md
    PRD.md
    PRODUCT_VISION.md
    ARCHITECTURE.md
    DATABASE.md
    API.md
    UI_UX.md
    ESPN_SYNC.md
    FINANCE_ENGINE.md
    ADMIN.md
    TESTING.md
    DEPLOYMENT.md
    AI_BUILD_GUIDE.md
    ROADMAP.md
    IMPLEMENTATION_PLAN.md
```

---

# Initial Milestones

## Phase 0

- Repository setup
- Documentation
- Folder structure
- Architecture

## Phase 1

- Database schema
- Supabase migrations
- Authentication
- Season configuration

## Phase 2

- Teams
- Owners
- Historical seasons
- Finance engine
- Ledger

## Phase 3

- ESPN synchronization
- Standings
- Weekly awards
- Statistics

## Phase 4

- Dashboard
- Team pages
- Financial pages
- History
- Admin tools

## Phase 5

- Automation
- Notifications
- Scheduled sync
- AI-generated weekly recaps

---

# Engineering Philosophy

- Favor simplicity.
- Prefer explicit code.
- Avoid premature abstraction.
- Write production-quality TypeScript.
- Test business logic.
- Keep documentation synchronized with code.

---

# AI Build Instructions

You are the lead software architect for this repository.

Rules:

1. Think before coding.
2. Prefer maintainability over cleverness.
3. Never hardcode league configuration.
4. Keep financial calculations deterministic.
5. Favor composition over inheritance.
6. Produce production-ready code.
7. Write tests for important business logic.
8. Document architectural decisions.
9. Work in logical milestones.
10. Keep documentation updated alongside implementation.

This repository should become the permanent home of the Sweet Looking Napa Dads Fantasy Football League and serve as an example of clean engineering, thoughtful product design, and maintainable software.
