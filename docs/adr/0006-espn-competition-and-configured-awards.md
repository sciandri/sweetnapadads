# ADR 0006 — Atomic ESPN competition sync and configured awards

- Status: accepted
- Date: 2026-07-31

## Context

ESPN supplies standings and completed matchup scores in one private-league
response. Weekly high-score payouts and low-score penalties affect the
financial ledger, so a partial sync or an application-coded amount could create
incorrect obligations. Exact high or low score ties also lack a historical
league rule.

## Decision

- Preserve the exact private response as commissioner-only raw evidence.
- Normalize standings, completed matchups, and reciprocal results, then cross
  one database transaction so invalid competition data rolls back together.
- Link source-owned ESPN matchups to the latest accepted sync run and update
  them only through stable source keys.
- Derive weekly awards only after a complete regular-season result set exists.
- Read every payout and penalty amount from season configuration. Placement,
  season, and future award schedules must follow the same rule; no monetary
  amount belongs in application constants.
- Keep the complete enabled schedule in `season_financial_rules`, replace it
  atomically through a commissioner-only function, and preserve every accepted
  version as immutable audit evidence. Legacy weekly setting columns are a
  compatibility projection only.
- Create immutable obligations for awards and penalties, separate from later
  payments.
- Store `commissioner_review` as the current season tie policy. Tied high or low
  scores create no award or obligation and are reported for explicit review.

## Consequences

Unique-score weeks can derive automatically and idempotently. Incomplete weeks
wait safely, while score corrections that conflict with an immutable derived
obligation fail closed. Supporting split or full-amount tie behavior will
require a reviewed season-policy expansion and a multi-recipient award model.
Commissioner configuration now covers weekly, placement, season-award, and
general penalty categories. New categories must enter the same audited model
before they can be automated; configuring a rule does not itself create an
obligation or payment.
