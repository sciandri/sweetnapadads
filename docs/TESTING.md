# Testing strategy

## Layers

- **Unit:** deterministic domain rules, money handling, scoring, ties, and
  payout allocation with Vitest.
- **Database:** migrations, constraints, functions, triggers, and RLS against a
  local Supabase instance.
- **Integration:** Route Handlers and ESPN normalization using recorded,
  redacted fixtures.
- **End-to-end:** login, member balance inspection, commissioner sync, and
  payment recording with Playwright.
- **Reconciliation:** 2025 accepted outputs compared to imported source totals.

## Required local checks

```bash
npm run lint
npm run typecheck
npm test
npm run db:reset
npm run db:lint
npm run db:test
npm run build
```

Database tests live in `supabase/tests/database/` and run with pgTAP against
the local Supabase PostgreSQL container. `db:lint` treats PostgreSQL warnings
as failures. Financial and authorization changes require tests at their owning
layer. The development-seed contract verifies the synthetic commissioner,
league, season rules, and commissioner authorization after every local reset.

Supabase environment parsing is unit-tested without real credentials. Auth
route tests must use synthetic identities and must cover expired sessions,
cookie refresh, login failure, and authorization denial before authenticated
screens ship.

The current Auth suite covers email normalization, local-only redirect
validation, supported email callback types, PKCE exchange, token-hash
verification, and generic expired-link handling. Database RLS tests cover
member, commissioner, and outsider authorization. Finance pgTAP coverage
verifies immutable events, source-key idempotency, compatible settlement
directions, payment and obligation allocation caps, reversible allocations,
audited adjustment reasons, exact reconciliation equations, canonical
team-perspective balances, and league-scoped view visibility.
Historical-import pgTAP coverage verifies lossless duplicate-row preservation,
immutable source evidence, mapping and blocker approval gates, terminal review
states, and commissioner-only staging access. The application suite also
checks that the 2025 workbook checksum and eight-sheet manifest remain exact.
It also requires an approved treatment for every manifest issue, verifies the
arithmetic of each champion-payout option, and reconciles the review-only
normalized preview without committing domain rows.

ESPN snapshot pgTAP coverage verifies raw evidence immutability, idempotent
sync keys, official-rank preservation, last-successful-snapshot behavior,
atomic snapshot switching, normalized member visibility, private raw-payload
isolation, and commissioner-only context assembly. Composer unit tests verify
that selections constrain the prompt, financial facts stay excluded, and the
system instructions prohibit recalculating ESPN standings or inventing facts.
The ingestion transaction suite additionally verifies service-role isolation,
complete team mapping, contiguous official ranks, exact retry behavior,
changed-evidence rejection, constraint enforcement, and all-or-nothing writes.

The canonical 2025 rehearsal adds a source-level contract over all 533 workbook
rows and their row hashes. Its local-only runner exercises the real Auth/RLS
approval path, commits the exact 117 KB approved preview, checks every stored
record count and reconciliation field, and then proves both RPC and operational
reruns are idempotent.

ESPN adapter coverage distinguishes completed-season final rank from
active-season playoff seed, rejects unavailable preseason ranks, requires an
exact season-team mapping, rounds scores deterministically, minimizes
member-readable source evidence, hashes raw responses deterministically, and
checks the atomic ingestion arguments. A synthetic twelve-team case verifies
that league size is derived from season mappings rather than a ten-team
application constant.
