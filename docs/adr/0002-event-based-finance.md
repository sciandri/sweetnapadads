# ADR 0002: Event-based finance model

- Status: Accepted
- Date: 2026-07-30

## Decision

Represent obligations, payments, allocations, reversals, and adjustments as
distinct immutable financial events. Calculate balances from those events
instead of storing a manually editable balance.

## Why

The workbook already distinguishes amounts owed from money moved. Separate
events preserve that distinction, make every balance explainable, support
partial settlement, and prevent historical edits from erasing evidence.

## Consequences

Commissioner corrections append events rather than editing posted rows.
Generated obligations require deterministic source keys. User interfaces must
show both outstanding position and settlement history.
