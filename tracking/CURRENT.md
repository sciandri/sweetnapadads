# Current project state

- Last updated: 2026-07-30
- Session: 0002
- Session status: complete — published and deployed
- Branch: `main`
- Phase: Phase 1 — Platform
- Checkpoint: Platform foundation published and deployed

## Current outcome

Phase 0 is complete and published. The repository now has a pinned Supabase
CLI, reproducible local Docker configuration, a tested platform-primitives
migration, database linting, pgTAP coverage, CI database verification, and an
authenticated project-scoped Supabase MCP connection for Codex. Leagues,
seasons, settings, profiles, memberships, and their RLS policies are now
implemented and tested locally. Request-scoped Supabase browser, server,
service-role, and session-refresh clients are in place for Next.js 16. The
reviewed migrations are applied to the hosted Supabase project, and Vercel
production is live at `https://www.sweetnapadads.com`.

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
- [x] Publish the verified foundation to GitHub.
- [x] Apply and verify both hosted Supabase migrations.
- [x] Configure the public Supabase production environment in Vercel.
- [x] Deploy and verify the production application and custom domain.

## Next actions

1. Seed a synthetic development league and commissioner identity.
2. Build the invite-only login and callback flow.
3. Configure local Supabase values for application development without
   committing them.
4. Add the service-role value to server environments only when a reviewed
   server-side feature requires it.
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
  authenticated, the CLI is linked, and both local migrations match the hosted
  migration history.
- Vercel production has the public Supabase URL and publishable key. Preview
  and development environments remain intentionally unconfigured to avoid
  silently sharing the production database.
- Docker Desktop must be running for local database commands.
- The repository is linked locally to Vercel project
  `prj_qNC8JhIZiZfvqlLPU66PYtlrwn7w` in the `sciandri` scope. Production
  deployment `dpl_5L67VVGSmAX9tk1agNe2LtXwzbGU` is Ready.
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
- Hosted migration history: local and remote versions match
- Vercel production: Ready
- `https://sweetnapadads.com`: HTTP 200 after redirect to
  `https://www.sweetnapadads.com/`
- Desktop visual pass: passing
- Responsive visual pass: passing at 320px, 390px, 768px, and 1440px with no
  horizontal overflow

## Latest commit intent

`docs: record platform deployment`

## Pickup instruction

Read `tracking/CHECKLIST.md`, confirm `main` is clean and synchronized, and
continue with the first incomplete item under **Next actions**.
