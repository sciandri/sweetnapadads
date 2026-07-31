# ADR 0005: ESPN standings and AI message context

- Status: Accepted
- Date: 2026-07-31

## Decision

Treat ESPN's reported standings order as canonical. Preserve each successful
standings response as an immutable raw payload plus a normalized snapshot whose
entries retain ESPN's rank and source identifiers. Do not derive or reorder
standings locally.

Use those normalized snapshots, selected weekly competition facts, and
commissioner-supplied notes as bounded context for a commissioner-only AI
message composer. The composer returns editable drafts for copying into the
league's existing SMS thread and never sends messages itself.

## Why

ESPN already applies the league's authoritative standings and tiebreak logic.
Reimplementing that ordering could disagree with the platform members see.
Passing raw private payloads or asking a model to calculate standings would
weaken provenance and make factual errors harder to detect.

The league already has a standing group-text thread. Building phone storage,
SMS delivery, carrier registration, consent automation, and delivery webhooks
would add operational burden without improving the actual workflow.

## Consequences

Standings remain available from the last successful snapshot when ESPN is
temporarily unavailable, with a visible capture timestamp. Every normalized
entry traces to the raw payload and sync run. The model sees only selected,
authorized, normalized facts and never sees ESPN credentials, raw private
responses, member phone numbers, or financial data.

AI output is advisory content. A commissioner must review, edit if necessary,
and explicitly copy the text. There is no application send action.
