# ADR 0007: Accepted-result projections and notification evidence

- Status: Accepted
- Date: 2026-08-02

## Decision

Keep imported, ESPN, and manual competition evidence immutable. A correction
is a new commissioner-authored batch linked to the prior accepted week. Member
and downstream reads use security-invoker accepted-result projections where the
latest correction wins and a manually supplied missing week takes precedence
over any later ESPN rows for that week.

Reconcile award changes with append-only financial adjustments and replacement
obligations. Never update or delete the prior obligation to make a correction
appear current.

Model league notifications and per-recipient delivery status as immutable
evidence. The first release delivers only in-app notices. Email and SMS channel
states do not authorize external delivery.

## Why

Source evidence may be wrong while remaining important audit history. A
projection makes the current answer unambiguous without destroying provenance.
The same append-only principle keeps financial balances explainable when an
award moves or disappears.

Notification evidence separates publication from delivery transport. The
league can add email later without redesigning notices or implying that the
application sent a group text.

## Consequences

All member competition pages and AI context read accepted projections rather
than raw source tables. Corrections require complete-team evidence and one
transaction. Historical rows grow over time by design.

In-app publication is available immediately. SMTP remains a deployment gate
before email delivery or real-member invitation testing.
