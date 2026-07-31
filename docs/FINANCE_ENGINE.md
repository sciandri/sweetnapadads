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
  + audited adjustments
```

## Invariants

- Amounts are integer cents.
- Rules are season-scoped data.
- Generated obligations have unique source keys.
- Re-running derivation cannot duplicate an obligation.
- Posted entries are immutable.
- Corrections append a reversal or adjustment with actor and reason.
- Ledger totals reconcile to obligation and payment subledgers.

Tie handling and payout rounding are explicit season settings before the
engine is considered complete.
