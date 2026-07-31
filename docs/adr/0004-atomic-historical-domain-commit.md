# ADR 0004: Atomic historical domain commit

- Status: Accepted
- Date: 2026-07-31

## Decision

Commit an approved normalized historical preview through one PostgreSQL
security-definer function. The function writes all competition and financial
domain rows, records source provenance, verifies reconciliation, and advances
the import batch to `committed` in the same transaction.

The exact normalized JSON document is content-hashed and stored with the
commit. Repeating the same batch and document is a successful no-op; repeating
the batch with different content is rejected.

## Why

The 2025 workbook spans results, awards, obligations, payments, allocations,
and league cash. Committing those domains independently could expose partial
history, duplicate financial events on retry, or mark a batch complete before
its balances reconcile. Application-only orchestration would also make the
database authorization and rollback boundary weaker.

## Consequences

Only an authenticated active commissioner can invoke the commit. Stable source
keys and exact collision checks make retries deterministic. Imported rows are
immutable, and a provenance table links every committed record to its batch
and raw source references. Any mapping, matchup, award-link, or reconciliation
failure aborts the transaction and leaves the batch approved for correction.

The commit function accepts only the approved normalized contract; staging and
mapping the source remain separate commissioner-controlled steps.
