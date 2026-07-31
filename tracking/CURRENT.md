# Current project state

- Last updated: 2026-07-30
- Session: 0001
- Session status: complete locally — GitHub publication blocked
- Branch: `main`
- Phase: Phase 0 — Foundation
- Checkpoint: Initial foundation checkpoint committed locally

## Current outcome

The repository now has a Next.js 16 application scaffold, initial Napa
editorial visual language, TypeScript and Tailwind configuration, Vitest,
GitHub Actions CI, architecture documentation, ADRs, and a clean npm security
audit. The source workbook and briefs remain intact for staged migration.
The responsive interface has been verified from phone through desktop widths.

## In progress

- [x] Finish the Phase 0 visual and repository verification pass.
- [x] Confirm the final working-tree contents.
- [x] Run the local “update and track” closeout.
- [ ] Publish the initial checkpoint after GitHub authentication and `origin`
      are configured.

## Next actions

1. Re-authenticate GitHub CLI and configure the intended repository as
   `origin`.
2. Push `main` and set its upstream.
3. Begin Phase 1 with Supabase local configuration and the first schema
   migration.
4. Implement profiles, league memberships, roles, seasons, settings, and RLS.

## Decisions in force

- Next.js App Router on Vercel with Supabase PostgreSQL/Auth/RLS.
- GitHub Actions triggers the protected ESPN synchronization endpoint.
- Financial state is event-based: obligations and payments are separate.
- Money is represented as safe integer cents.
- Rules are season-scoped data rather than application constants.
- `tracking/CURRENT.md` is the canonical session pickup point.

## Known risks and blockers

- GitHub publication is blocked: no remote is configured, and the saved
  credentials for `IgniteIQ-Ryan` and `sciandri` are both invalid.
- The 2025 workbook contains documented reconciliation discrepancies; see
  `docs/MIGRATION_2025.md`.
- Supabase projects and environment values are not configured.
- ESPN private-league credentials have not been provided and must never be
  committed.
- `logo/sweetlookingnapadads.png` is the canonical and only supplied brand
  asset. It has not yet been integrated into the interface.

## Verification

- `npm audit`: clean
- `npm run lint`: passing
- `npm run typecheck`: passing
- `npm test`: 2 tests passing
- `npm run build`: passing
- Desktop visual pass: passing
- Responsive visual pass: passing at 320px, 390px, 768px, and 1440px with no
  horizontal overflow

## Latest commit intent

`chore: establish project foundation and session tracking`

## Pickup instruction

Read `tracking/CHECKLIST.md`, then continue with the first incomplete item
under **Next actions** above. Authenticate the intended GitHub account and
confirm the repository URL before adding `origin`; do not create or select a
repository by inference.
