# Session 0002 — Supabase foundation

- Date: 2026-07-30
- Status: complete — published and deployed
- Branch: `main`
- Starting commit: `72bb6ff`
- Ending source commit: `b208574`

## Goal

Establish a reproducible Supabase local-development environment and the first
versioned platform migration.

## Starting context

Phase 0 is complete and published. The repository has database architecture
documentation but no Supabase CLI configuration, migrations, or local schema
verification yet.

## Work completed

- [x] Confirm the clean `main` branch tracks `origin/main`.
- [x] Review the project foundation, database plan, and current official
      Supabase local-development guidance.
- [x] Add the pinned Supabase CLI configuration and package scripts.
- [x] Add and document the first platform-primitives migration.
- [x] Add pgTAP contract coverage for the foundational schema.
- [x] Rebuild, lint, and validate the local database from migrations.
- [x] Add database verification to GitHub Actions.
- [x] Record the hosted `sweetnapadads` project URL and project ref.
- [x] Configure and authenticate the project-scoped Supabase MCP server for
      Codex.
- [x] Record that the Vercel project `sweetnapadads` has been created.
- [x] Attempt the official Vercel plugin installer; its Claude target installed,
      but the Codex target failed because `vercel@openai-curated` is not
      available in the configured Codex marketplaces.
- [x] Authenticate Vercel as `sciandri-7552` and link the existing
      `sciandri/sweetnapadads` project without deploying.
- [x] Authenticate the Supabase CLI and link hosted project
      `cleyfpzxckjtmsoesgby`.
- [x] Confirm the hosted migration dry-run contains only the two intended
      migrations.
- [x] Add leagues, seasons, settings, profiles, and memberships.
- [x] Add league-scoped grants, RLS helpers, and policies.
- [x] Add database tests for Auth profile creation and member, commissioner,
      and outsider access boundaries.
- [x] Add request-scoped Supabase browser, server, and service-role clients.
- [x] Add the Next.js 16 Proxy session-refresh boundary using verified claims.
- [x] Validate public/server environment separation with unit tests.
- [x] Run the complete application, database, build, tracking, and security
      closeout gates.
- [x] Expand “update and track” to include Supabase and Vercel deployment.
- [x] Configure the public Supabase URL and publishable key for Vercel
      production without printing or committing their values.
- [x] Commit and push the verified platform foundation to GitHub.
- [x] Apply both reviewed migrations to the hosted Supabase project.
- [x] Verify local and hosted Supabase migration histories match.
- [x] Deploy Vercel production and verify the custom domain returns the
      expected application.

## Decisions

- Use versioned imperative SQL migrations as the single schema representation.
- Pass `--local` explicitly for local database commands where supported.

## Verification

- `npm run db:start`: passing
- `npm run db:reset`: passing
- `npm run db:lint`: passing with no warnings
- `npm run db:test`: 24 passing
- `npm run lint`: passing
- `npm run tracking:check`: passing
- `npm run typecheck`: passing
- `npm test`: 5 passing
- `npm run build`: passing outside the restricted sandbox
- `npm audit`: zero known vulnerabilities
- `npx supabase migration list --linked`: both local and remote migration
  versions match
- Vercel deployment `dpl_5L67VVGSmAX9tk1agNe2LtXwzbGU`: Ready
- `https://sweetnapadads.com`: HTTP 200 after redirect to
  `https://www.sweetnapadads.com/`

## Remaining risks

- Preview and development Vercel environments are intentionally not connected
  to the production Supabase project.
- The service-role value is not configured in Vercel because the deployed
  application does not yet use the admin client.
- ESPN private-league credentials have not been provided.

## Exact handoff

Read `tracking/CURRENT.md`, confirm `main` is clean and synchronized, then seed
a synthetic development league and commissioner identity before building the
invite-only login and callback flow.
