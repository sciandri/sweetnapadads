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

## Non-goals

- Live lineup management
- Waiver or trade execution
- Replicating ESPN roster and scoring interfaces
- Public self-registration

## Acceptance

A feature is complete only when implemented, tested, documented, and
reconciled where historical data is involved.
