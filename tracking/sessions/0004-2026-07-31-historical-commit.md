# Session 0004 — Historical domain commit

- Date: 2026-07-31
- Status: complete — published and deployed
- Branch: `main`
- Starting commit: `e85da01`
- Ending source commit: `8bdeeef`

## Goal

Commit the approved 2025 normalized preview into durable competition and
financial domain tables through one atomic, idempotent, provenance-preserving
workflow.

The session scope later expanded to establish the canonical ESPN standings
layer and the commissioner message-composer foundation. This remains the same
active session because no `update and track` release checkpoint has occurred.

## Starting context

Session 0003 published the authenticated league and finance foundation. The
2025 preview is approved and reconciled, but domain commit is intentionally
blocked behind a separate transaction. Competition result and award tables do
not yet exist, so they are a prerequisite for a complete historical commit.
Production SMTP is also pending external provider credentials, but does not
block local historical-import implementation.

## Work completed

- [x] Confirm clean, synchronized `main` at `e85da01`.
- [x] Re-read canonical tracking, the project foundation, migration contract,
      approved preview, and current database boundaries.
- [x] Add the minimal competition-history schema required by the preview.
- [x] Add the atomic, idempotent historical domain commit function.
- [x] Add reconciliation, rollback, RLS, and repeat-run database tests.
- [x] Update import, database, finance, and tracking documentation.
- [x] Preserve immutable raw ESPN responses and normalized standings snapshots.
- [x] Preserve ESPN's official rank as canonical and test last-successful
      snapshot behavior.
- [x] Add the commissioner-only, finance-excluding message context function.
- [x] Add prompt-boundary unit tests that forbid invented facts and local
      standings recalculation.
- [x] Add the responsive commissioner composer, fact review, manual editing,
      and clipboard workflow.
- [x] Add the atomic, service-role-only ESPN standings ingestion function.
- [x] Test complete team mapping, official rank integrity, exact retry safety,
      changed-evidence rejection, and rollback of partial writes.
- [x] Document the copy-only group-thread workflow and the absence of SMS
      delivery or phone storage.
- [x] Run the complete application, database, build, and tracking release
      gates.
- [x] Commit and push source checkpoint `8bdeeef` to GitHub `main`.
- [x] Dry-run, apply, and verify migrations `20260731100000` through
      `20260731140000` on hosted Supabase.
- [x] Deploy production as `dpl_2vcpKeionBYH1ob7s9zfBcKyey8u`.
- [x] Verify GitHub authentication, hosted migration history, deployment
      aliases, homepage, login, and protected composer redirect.
- [ ] Stage the canonical 2025 season and team mappings, then invoke the
      verified commit with the approved preview.
- [ ] Configure the server-only OpenAI key and enable live generation through
      an authenticated, commissioner-only Route Handler.

## Decisions

- Build the competition-history dependency before the commit function so the
  approved preview is committed as a whole rather than partially.
- Store the exact normalized preview and one provenance link per committed
  record so a batch can always be audited back to source evidence.
- Treat an exact same-preview retry as success and reject a changed retry.
- Treat ESPN's official standings order as authoritative; never derive a local
  replacement for ESPN's tiebreak ordering.
- Generate editable copy for the league's existing SMS thread; do not build an
  SMS provider integration or store member phone numbers.
- Pass only selected normalized facts and commissioner notes to the model;
  exclude finances, credentials, and raw private ESPN payloads.

## Verification

- `npm run lint`: passing
- `npm run tracking:check`: passing
- `npm run typecheck`: passing
- `npm test`: 28 tests passing
- `npm run build`: passing
- `npm run db:reset`: passing
- `npm run db:lint`: passing with no warnings
- `npm run db:test`: 255 tests passing
- GitHub `main`: source checkpoint `8bdeeef` synchronized
- Hosted Supabase: all twelve migrations through `20260731140000` match
- Vercel deployment `dpl_2vcpKeionBYH1ob7s9zfBcKyey8u`: Ready
- Production home and login: HTTP 200
- Unauthenticated composer: safe redirect to login

## Risks or blockers

- Production SMTP needs an external provider and credentials before real
  invitations; it is independent of this local implementation.
- The canonical 2025 import cannot be invoked until its actual league, season,
  staged source evidence, and ten mapped season teams exist.
- Live AI generation is blocked only by the absent server-side OpenAI API key;
  the authorized context boundary and honest disabled-state UI are complete.
- ESPN fetching requires private-league credentials; the storage,
  normalization, RLS, and context contracts are complete without them.

## Exact handoff

Start session 0005 from clean, synchronized `main`. Configure the server-only
OpenAI key and implement the authenticated generation Route Handler. If
credentials remain unavailable, build the ESPN adapter or stage the canonical
2025 import context, then invoke the approved preview through
`commit_historical_import` and verify its reconciliation.
