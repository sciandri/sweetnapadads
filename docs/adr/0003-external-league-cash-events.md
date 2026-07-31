# ADR 0003: External league cash events

- Status: Accepted
- Date: 2026-07-30

## Decision

Represent cash moving between the league and a non-team counterparty as an
immutable external cash event. Keep these events separate from team-scoped
obligations, payments, allocations, and adjustments.

## Why

The 2025 workbook records a $700 draft-party expense paid outside the league.
Attendee fees are still team obligations and team payments, but the vendor
expense has no season team. Assigning it to a team would corrupt team balances;
omitting it would overstate league cash by $700.

## Consequences

Season cash is derived from team payments plus external cash events. External
events use stable season-scoped source keys, are append-only, and may omit an
exact date only for imported historical evidence. A team payment must never be
duplicated as an external event.
