# Current project state

- Last updated: 2026-07-30
- Session: 0001
- Session status: complete and published
- Branch: `main`
- Phase: Phase 0 — Foundation
- Checkpoint: Initial foundation checkpoint published to GitHub

## Current outcome

The repository now has a Next.js 16 application scaffold, initial Napa
editorial visual language, TypeScript and Tailwind configuration, Vitest,
GitHub Actions CI, architecture documentation, ADRs, and a clean npm security
audit. The source workbook and briefs remain intact for staged migration.
The responsive interface has been verified from phone through desktop widths.

## In progress

- [x] Finish the Phase 0 visual and repository verification pass.
- [x] Confirm the final working-tree contents.
- [x] Run the “update and track” closeout.
- [x] Publish the initial checkpoint to GitHub.

## Next actions

1. Begin Phase 1 with Supabase local configuration and the first schema
   migration.
2. Implement profiles, league memberships, roles, seasons, settings, and RLS.
3. Integrate the supplied logo into the interface when the branded application
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

`docs: record initial GitHub publication`

## Pickup instruction

Read `tracking/CHECKLIST.md`, then continue with the first incomplete item
under **Next actions** above. Confirm `git status` is clean and `main` is
tracking `origin/main` before beginning Phase 1.
