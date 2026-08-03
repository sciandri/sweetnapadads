# Product requirements

## Product

Sweet Looking Napa Dads is the league headquarters for competition,
financial transparency, history, commissioner operations, and league culture.
It complements ESPN instead of recreating ESPN.

## Outcomes

- Commissioner maintenance takes less than five minutes per week.
- ESPN synchronization is idempotent and preserves its raw source payload.
- Derived results reconcile exactly to the accepted historical baseline.
- Every financial balance is explainable from immutable events.
- Season rules can change without code changes.
- Commissioners can turn verified league facts into editable AI-assisted group
  messages without sending communications from the application.

## Users

- **Member:** views league information, personal balances, and history.
- **Commissioner:** configures seasons, resolves sync issues, records payments,
  publishes content, and performs audited adjustments.

## Initial scope

1. Season and team configuration
2. Authentication and authorization
3. Financial obligations, payments, and balances
4. ESPN results, standings, and weekly awards
5. Historical 2025 import and reconciliation
6. Member dashboard and commissioner tools
7. Commissioner-only AI message composer with ESPN standings and result
   context plus copy-to-clipboard handoff

## Non-goals

- Live lineup management
- Waiver or trade execution
- Replicating ESPN roster and scoring interfaces
- Public self-registration
- Sending SMS, managing a group-text thread, or storing recipient phone numbers

## Acceptance

A feature is complete only when implemented, tested, documented, and
reconciled where historical data is involved.

## Commissioner message composer

The application generates drafts for the league's existing standing SMS
thread; it does not send messages. A commissioner chooses a season and week,
selects which verified facts to include, adds optional notes and tone guidance,
reviews the generated text, and copies the final draft.

Generator context may include:

- ESPN's official standings order from the latest successful snapshot;
- selected weekly results and scores;
- weekly awards when available;
- league and season identity; and
- commissioner-supplied facts and instructions.

The model may summarize supplied facts but must not calculate, reorder, or
invent standings, scores, balances, dates, or awards. Financial context is
excluded from the initial composer.
