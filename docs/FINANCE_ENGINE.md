# Finance engine

## Model

An obligation describes what should be paid. A payment describes money that
actually moved. They are never the same record.

Obligation examples:

- league dues owed by a team;
- low-score penalty owed to the league;
- weekly high-score payout owed to a team;
- placement payout owed to a team.

Payment examples:

- dues received;
- penalty received;
- payout disbursed.

Cash paid to or received from a non-team counterparty is an
`external_cash_event`, not a team payment. For example, attendee draft-party
fees remain team obligations and payments, while the venue expense is a
separate league cash-out event.

## Sign convention

Balances are presented from the team's perspective:

- positive: team owes the league;
- negative: league owes the team;
- zero: settled.

```text
team balance =
  obligations owed by team
  - payments received from team
  - obligations owed to team
  + payments made to team
  + adjustments that increase the team balance
  - adjustments that decrease the team balance
```

## Invariants

- Amounts are integer cents.
- Rules are season-scoped data.
- Generated obligations have unique source keys.
- Re-running derivation cannot duplicate an obligation.
- Posted entries are immutable.
- Corrections append a reversal or adjustment with actor and reason.
- Ledger totals reconcile to obligation and payment subledgers.
- Historical domain commits recompute all financial and cash totals inside the
  same transaction that creates the imported events.

The database exposes `team_financial_balances`,
`obligation_reconciliation`, and `payment_reconciliation` as
security-invoker views. These are the canonical read models for application
balances and settlement state.

`season_cash_balances` is the canonical league-cash read model:

```text
season cash =
  payments received from teams
  - payments made to teams
  + external cash received
  - external cash paid
```

Tie handling and payout rounding are explicit season settings before the
engine is considered complete.
