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
- Every payout and penalty amount and schedule is season configuration; no
  monetary rule is an application constant.
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

The authenticated member finance page is implemented at
`/dashboard/finances`. It presents league-wide team balances, a selected team's
six canonical components, immutable obligation/payment/adjustment events, and
reconciled outstanding or unallocated amounts. Positive and negative balances
retain the team-perspective sign convention. The page deliberately keeps
actual cash in a separately labeled summary because obligations do not prove
that money moved.

`season_financial_rules` is the canonical season schedule. It stores required
weekly high/low rules plus commissioner-defined placement payouts, season
awards, and penalties. The complete enabled schedule is validated and replaced
atomically, and every accepted version is preserved as an immutable audit
snapshot. Configuration never records money movement.

Unique-score weeks create obligations automatically after every active team has
one accepted regular-season result. The derivation currently reads compatibility
values projected into `season_settings` by the canonical rule transaction. The
season-scoped tie policy is `commissioner_review`: tied high or low scores create
no financial event and remain pending explicit resolution. Placement and other
season-rule derivation will be enabled only after their triggering competition
facts and review policies are modeled. Tie handling and payout rounding remain
explicit season policy rather than hidden code behavior.
