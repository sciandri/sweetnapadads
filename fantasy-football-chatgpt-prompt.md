# ChatGPT Prompt: Fantasy Football League Webapp — Sweet Looking Napa Dads

---

## CONTEXT

I run a 10-team fantasy football league called **Sweet Looking Napa Dads**. Last season I tracked everything manually in a Google Sheets spreadsheet. I would pull weekly matchup scores from ESPN Fantasy Football every Monday night or Tuesday morning, paste them into the spreadsheet, and let the formulas calculate payouts, penalties, and balances.

I want to rebuild this as a **webapp** with the following goals:
1. Automate the ESPN data pull (so I don't have to manually enter scores each week)
2. Allow all 10 league members to **log in** and see their own balance, transaction history, and league-wide financial transparency (who got paid, who owes what, how much is in the pool)
3. Remain **100% free** — every technology choice must have a free tier that handles our use case (10 users, one season of data, light traffic)

---

## ⚠️ IMPORTANT: Before writing any code

**First, provide a complete technical architecture summary.** Break it down section by section:
- What tech stack you're recommending and why
- Each component/service you're using (frontend, backend, database, auth, hosting, ESPN integration)
- What the data model looks like (tables, relationships, key fields)
- How the ESPN automation will work (polling mechanism, data flow)
- How authentication/authorization will work (login, role-based views)
- Any risks, limitations, or tradeoffs on the free tier

**Only after I approve the architecture should you start generating code.** If I have questions or want changes to the plan, address those first.

---

## LEAGUE RULES & FINANCIAL LOGIC

Here is exactly how the league works financially. Replicate this logic precisely.

### Teams
- 10 teams
- Each team has: team name, owner email address
- Buy-in: **$200/team** ($2,000 total prize pool)
- Optional draft party fee: **$100/team** (not all teams pay this)

### Weekly Rules (per NFL week, Weeks 1–14 regular season)
- Each week has 5 matchups (head-to-head)
- The team with the **highest score** that week across all 10 teams wins **$50** (called "Payout Obligation" — owed to them from the league)
- The team with the **lowest score** that week across all 10 teams is assessed a **$20 penalty** (they owe the league $20)
- These are tracked as obligations/assessments, and separately as paid/received

### Season-End Prize Pool Distribution
The prize pool ($2,000) is distributed as follows:
1. **Weekly High Score payouts:** $50 × 14 weeks = $700 (paid out weekly as they happen)
2. **Season-Long Highest Single-Week Score:** 5% of prize pool ($100) — the team that posted the single highest score across all 14 weeks gets this at season end
3. **Remaining pool** after the above = $2,000 − $700 − $100 = $1,200 distributed to the top 3 playoff finishers:
   - Champion: 60% of $1,200 = $720
   - Runner-up: 30% of $1,200 = $360
   - 3rd Place: 10% of $1,200 = $120

### Transaction Types (from the League Ledger)
Every financial event is logged with: team name, email, date, method (Venmo, Cash, etc.), amount, and a type. The types are:
- **Dues** — buy-in payment received
- **Draft Party** — draft party fee payment received
- **Penalty Assessed** — low score penalty owed by a team (negative for team)
- **Penalty Paid** — low score penalty actually paid (settled)
- **Payout Obligation** — high score payout owed TO a team (positive for team)
- **Payout Paid** — high score payout actually delivered to a team (settled)

### Team Balance Formula
For each team, calculate:
- **Dues Balance** = $200 − amount of Dues paid = how much dues they still owe (0 = paid up)
- **Draft Party Balance** = $100 − Draft Party paid (if applicable)
- **Penalty Net** = Penalties Assessed − Penalties Paid (positive = still owe)
- **Payout Net** = Payout Obligations − Payouts Paid (positive = league still owes them)
- **Net Balance** = Dues Balance + Draft Party Balance + Penalty Net − Payout Net
  - Negative = league owes them money
  - Positive = they owe the league money

---

## DATA INPUT: HOW ESPN SCORES ARE ENTERED

### Manual flow (what I did last year):
Every Monday/Tuesday I opened ESPN Fantasy Football, noted each matchup result (Team A vs. Team B, their scores, W/L), and pasted them into the **Weekly Results** tab.

Each row in Weekly Results = one team's game entry:
- Week number
- Team Name
- Score (fantasy points, e.g., 130.54)
- Opponent (team name)
- Result (W or L)

Note: each matchup creates 2 rows — one per team.

### Automated flow (what I want):
- Auto-pull weekly matchup results from ESPN Fantasy Football API after each week locks
- My ESPN league is a **private ESPN fantasy league** — I'll provide the League ID, and the ESPN auth cookies (S2 and SWID cookies, used by the unofficial ESPN API)
- This should run automatically each week (Monday night or Tuesday morning) as a scheduled job
- If automation fails, I need a manual fallback to enter scores via the webapp admin panel

---

## ESPN FANTASY API NOTES

ESPN does not have an official public API, but there is a well-known unofficial REST endpoint:
```
GET https://fantasy.espn.com/apis/v3/games/ffl/seasons/{year}/segments/0/leagues/{leagueId}?view=mMatchup&view=mMatchupScore&scoringPeriodId={week}
```
Headers required for private leagues:
```
Cookie: espn_s2=<S2_VALUE>; SWID=<SWID_VALUE>
```

Alternatively, the Python library `espn-api` (pip install espn-api) can handle this cleanly:
```python
from espn_api.football import League
league = League(league_id=LEAGUE_ID, year=2025, espn_s2='...', swid='...')
box_scores = league.box_scores(week=1)
```

The ESPN team names in the fantasy app may differ slightly from the team names in my database — build a **team name mapping** table so I can manually map ESPN display names to the canonical team names in my system.

---

## WEBAPP FEATURES REQUIRED

### Public / League Member View (after login)
1. **My Dashboard** — logged in user sees:
   - Their team name
   - Their current net balance (positive = they owe league, negative = league owes them)
   - Breakdown: dues status, draft party status, weekly penalties owed/paid, payouts earned/received
   - Their week-by-week record (W/L, score per week)

2. **League Standings** — all 10 teams ranked by record, with win/loss, points for, points against

3. **Weekly Results** — browse by week: all matchup results for any given week, with high/low score winners highlighted

4. **Financial Transparency Page** (this is the core reason for the webapp) — all 10 teams shown with:
   - Current balance (color-coded: green = league owes them, red = they owe league)
   - Breakdown of dues, penalties, payouts
   - Full league ledger (all transactions, searchable/filterable by team or type)
   - Total prize pool collected, total paid out, remaining balance

5. **Weekly Awards** — per week: who had the high score ($50 payout), who had the low score ($20 penalty)

6. **Side Bets** — optional page showing any side bets between teams (just a simple table: Team A vs Team B, description, amount)

### Admin View (commissioner only — me)
1. **Enter Weekly Results** (manual fallback) — form to input all matchup results for a given week
2. **Trigger ESPN Sync** — button to manually kick off the ESPN data pull for a given week
3. **League Ledger Management** — add/edit/delete ledger entries (mark penalties as paid, record payouts, record dues payments)
4. **Season-End Payouts** — input playoff results (1st/2nd/3rd) and let the system calculate final payout amounts

---

## AUTHENTICATION REQUIREMENTS

- Each team member logs in with their **email address** (the emails I provide in the teams table)
- **No self-registration** — I provision the accounts, members just set their password
- After login, members can only see their own dashboard by default, but can browse the public financial pages
- Only I (the commissioner/admin) can access admin functions
- Use a secure, free auth solution — **Supabase Auth** is preferred

---

## TECH CONSTRAINTS

- **Everything must be free tier** — no paid plans, no credit card required for basic operation
- 10 users max, one NFL season of data (~17 weeks), light traffic (people check it a few times a week max)
- Prefer a **JavaScript/TypeScript** stack for the frontend (React or Next.js)
- The backend/API and database should ideally be **Supabase** (free tier: 500MB DB, 50MB file storage, 50K monthly active users — more than enough)
- Frontend hosting: **Vercel** (free hobby tier)
- Scheduled jobs for ESPN automation: **Vercel Cron Jobs** (free on hobby plan, limited to 2 invocations/day — enough for once-weekly runs) OR **GitHub Actions** on a schedule (completely free)
- The ESPN S2 and SWID cookies should be stored as **environment variables** (not in code)

---

## SUGGESTED ARCHITECTURE (for you to validate or improve on)

I'm thinking:
- **Next.js** (App Router) deployed on **Vercel** — handles both frontend and API routes
- **Supabase** — PostgreSQL database + Supabase Auth (email/password) + Row Level Security so users only see their own sensitive data
- **Supabase DB tables** mirroring the spreadsheet:
  - `teams` (id, name, email, horse_name, bio, attended_draft_party)
  - `league_config` (buy_in, draft_party_fee, weeks, weekly_high_payout, weekly_low_penalty, season_high_pct, champion_pct, runner_up_pct, third_pct)
  - `weekly_results` (id, week, team_id, score, opponent_id, result)
  - `league_ledger` (id, team_id, date, method, amount, type)
  - `side_bets` (id, team1_id, team2_id, description, amount)
  - `espn_team_map` (espn_name, team_id) — for mapping ESPN names to DB teams
- **ESPN sync**: a Next.js API route (`/api/sync-espn`) that pulls scores for a given week using the `espn-api` approach, triggered by Vercel Cron or manual admin button
- **Views/computed data**: team balances computed on the fly from the ledger (or as a Supabase view/function) — same math as the spreadsheet formulas

Validate this, improve on it, flag any issues, and then walk me through the complete plan before writing any code.

---

## WHAT I'LL PROVIDE WHEN READY TO BUILD

Once architecture is approved, I'll provide:
1. The 10 team names and email addresses
2. My ESPN League ID
3. The S2 and SWID cookies (as environment variables, not in code)
4. Confirmation of any league rule details I want to adjust

---

## FINAL INSTRUCTIONS TO YOU (ChatGPT)

1. **Do not write any code until I approve the architecture plan.**
2. Give me the architecture summary in clearly labeled sections (stack, data model, ESPN integration, auth, hosting, automation).
3. After I approve, build this **step by step** — start with the database schema and seed data, then auth, then the data model/API layer, then the frontend pages, then the ESPN automation last.
4. Every code file should be complete and production-ready, not pseudocode or placeholders.
5. Include comments in code explaining non-obvious logic, especially the financial calculations.
6. At each major step, tell me what to do (what to copy where, what commands to run, what to configure in Supabase/Vercel).
7. Flag any free-tier limits I should be aware of and how to stay within them.
