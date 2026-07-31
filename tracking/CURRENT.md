# Current project state

- Last updated: 2026-07-30
- Session: 0002
- Session status: closing — publish and deployment in progress
- Branch: `main`
- Phase: Phase 1 — Platform
- Checkpoint: Platform foundation verified and ready to publish

## Current outcome

Phase 0 is complete and published. The repository now has a pinned Supabase
CLI, reproducible local Docker configuration, a tested platform-primitives
migration, database linting, pgTAP coverage, CI database verification, and an
authenticated project-scoped Supabase MCP connection for Codex. Leagues,
seasons, settings, profiles, memberships, and their RLS policies are now
implemented and tested locally. Request-scoped Supabase browser, server,
service-role, and session-refresh clients are in place for Next.js 16.

## In progress

- [x] Initialize and verify the local Supabase stack.
- [x] Add the first platform-primitives migration.
- [x] Document the local database workflow and next schema boundary.
- [x] Authenticate the Supabase CLI and link project
      `cleyfpzxckjtmsoesgby`.
- [x] Preview both pending hosted migrations without applying them.
- [x] Link the repository to the existing Vercel project `sweetnapadads`.
- [x] Implement and test the league platform schema and RLS.
- [x] Implement Supabase SSR browser/server clients and the Next.js Proxy.

## Next actions

1. Finish the active publish-and-deploy ritual.
2. Configure Supabase publishable and service-role values locally and in
   Vercel without committing them.
3. Seed a synthetic development league and commissioner identity.
4. Build the invite-only login and callback flow.
5. Integrate the supplied logo into the interface when the branded application
   shell is implemented.

## Decisions in force

- Next.js App Router on Vercel with Supabase PostgreSQL/Auth/RLS.
- GitHub Actions triggers the protected ESPN synchronization endpoint.
- Financial state is event-based: obligations and payments are separate.
- Money is represented as safe integer cents.
- Rules are season-scoped data rather than application constants.
- `tracking/CURRENT.md` is the canonical session pickup point.

## Known risks and blockers

- The 2025 workbook contains documented reconciliation discrepancies; see
  `docs/MIGRATION_2025.md`.
- The hosted `sweetnapadads` project exists at
  `https://cleyfpzxckjtmsoesgby.supabase.co`. Codex MCP and CLI access are
  authenticated and the CLI is linked, but application environment keys are
  not configured.
- The two local migrations are pending on the hosted Supabase database; the
  verified dry-run contains no other changes.
- Docker Desktop must be running for local database commands.
- The repository is linked locally to Vercel project
  `prj_qNC8JhIZiZfvqlLPU66PYtlrwn7w` in the `sciandri` scope. It has not been
  deployed from this working tree.
- ESPN private-league credentials have not been provided and must never be
  committed.
- `logo/sweetlookingnapadads.png` is the canonical and only supplied brand
  asset. It has not yet been integrated into the interface.

## Verification

- `npm audit`: clean
- `npm run lint`: passing
- `npm run typecheck`: passing
- `npm test`: 5 tests passing
- `npm run db:reset`: passing
- `npm run db:lint`: passing with no warnings
- `npm run db:test`: 24 database tests passing
- `npm run build`: passing
- Desktop visual pass: passing
- Responsive visual pass: passing at 320px, 390px, 768px, and 1440px with no
  horizontal overflow

## Latest commit intent

`feat: add platform schema, RLS, and Supabase Auth foundation`

## Pickup instruction

If this closeout was interrupted, resume the publish-and-deploy ritual from the
first incomplete external step. Otherwise read `tracking/CHECKLIST.md`, confirm
`main` is clean and synchronized, and continue with the first incomplete item
under **Next actions**.
