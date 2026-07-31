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

The synchronization Route Handler suite covers malformed and non-JSON bodies,
missing authentication, commissioner denial, constant-time automation-secret
authorization, dynamic twelve-team mapping propagation, caller-supplied
idempotency keys, unmapped teams, missing configuration, ESPN failures,
unavailable preseason order, persistence failures, missing seasons, and the
stable unexpected-error boundary. Tests assert that private error details do
not cross the HTTP response.

Mapping administration pgTAP coverage verifies the audited table and function,
authenticated/anonymous privileges, safe ESPN ID swaps, exact team coverage,
unique IDs, RLS-hidden seasons, commissioner audit visibility, and exact
accepted evidence. HTTP coverage verifies identity, role, RLS-hidden seasons,
twelve-team batches, stable rejections, and error redaction. The live local
browser pass exercises magic-link Auth, an audited mapping save, disabled-sync
guidance, recent-run empty state, and a 390px layout with no horizontal
overflow.

The operations contract test pins the ESPN workflow to manual-only execution,
least-privilege permissions, indirect GitHub secret and variable references,
evidence-derived idempotency, redacted output, and the documented activation,
failure, rotation, and scheduling gates. The workflow YAML is parsed locally.

Member standings view tests pin display ordering to ESPN's supplied
`official_rank`, preserve two-decimal fantasy points, and format the evidence
capture time in a fixed league time zone. Authenticated browser checks cover
the desktop dashboard and its 390px mobile empty state after a clean database
reset.

Member competition view tests verify descending week order, reciprocal matchup
grouping, winner-first presentation, exact hundredth formatting, incomplete
result states, and stored award labels without recomputation. Authenticated
browser checks use the rehearsed 2025 history to cover season/week navigation,
populated scorecards, weekly honors, postseason pending states, and the 390px
responsive layout.

Member finance view tests verify team-perspective status labels, deterministic
balance ordering, league/team summary grouping, immutable event isolation, and
joins to canonical obligation/payment reconciliation. Authenticated browser
checks cover the seeded component formula, locally rehearsed ten-team 2025
ledger, settled and outstanding states, event remainder labels, actual-cash
separation, and the 390px responsive layout.

Team-history unit coverage verifies newest-first season ordering, reciprocal
opponent score aggregation, win/loss/tie summaries, stored award counts,
canonical balance attachment, empty-season behavior, and current-first dated
ownership labels. Authenticated browser checks cover the seeded linked owner,
the rehearsed ten-team 2025 directory, an honest missing-owner state, populated
franchise statistics, evidence links, and the 390px detail layout.

League-activity unit coverage verifies winner-first accepted results, exact
score formatting, tied and incomplete states, separate stored honors, and
date-ordered immutable financial event types. Authenticated browser checks
cover the seeded financial-only state, populated 2025 competition and finance
streams, desktop presentation, and the stacked 390px layout.

ESPN matchup fixtures and live redacted shape inspection cover completed games,
ties, undecided and future exclusion, score rounding, reciprocal opponents,
dynamic playoff boundaries, mapping failures, and duplicate identifiers. The
database suite verifies service-role isolation, raw-run provenance, exact
retry behavior, score/outcome consistency, and rollback of the entire
competition snapshot when a matchup fails.

Weekly award pgTAP coverage verifies season-scoped tie policy, service-role
isolation, complete-team result gates, unique high/low selection, configured
integer-cent payout and penalty amounts, correct obligation directions,
deterministic occurrence dates and source references, exact retries, and
fail-closed tied weeks with no partial financial events.

Season financial-rule pgTAP coverage verifies initialization, member and
commissioner visibility, direct-write denial, commissioner-only batch saves,
all five rule kinds, direction and placement constraints, legacy weekly
projections, immutable audit evidence, and outsider denial. Unit and HTTP tests
cover strict safe-integer parsing, complete-schedule requirements, duplicate
keys and ranks, verified claims, RLS-hidden seasons, stable error responses, and
the audited RPC call. Authenticated browser review covers the editor at desktop
and 390px widths.
