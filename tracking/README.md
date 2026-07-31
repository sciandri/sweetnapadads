# Session tracking

This folder is the durable memory of the project. GitHub stores it with the
code, making `CURRENT.md` the canonical pickup point for every new session.

## Files

- `CURRENT.md`: exactly where the project stands and what happens next.
- `CHECKLIST.md`: authoritative milestone and task checklist.
- `sessions/`: append-only record of completed and active sessions.
- `templates/SESSION.md`: template for a new session record.

Product and architecture truth still lives in `docs/` and ADRs. Tracking
records execution state and links to that truth instead of duplicating it.

## Start-of-session ritual

1. Read `CURRENT.md`.
2. Read `CHECKLIST.md`.
3. Read the latest entry in `sessions/`.
4. Confirm the current branch and working-tree state.
5. Read the product documentation relevant to the next action.
6. Continue from the first item under **Next actions** in `CURRENT.md`.

If repository reality disagrees with tracking, stop and reconcile the files
before implementation. Never silently assume which one is newer.

## During a session

- Keep the active session log concise.
- Update the checklist when a task materially changes state.
- Record durable technical decisions in `docs/adr/`, then link them from the
  session log.
- Put newly discovered risks or blockers in `CURRENT.md`.
- Do not use session tracking as a substitute for tests or subsystem docs.

## “Update and track” publish-and-deploy ritual

The phrase **update and track** authorizes this entire sequence, including
production deployment to the linked Supabase and Vercel projects:

1. Run:

   ```bash
   npm run lint
   npm run tracking:check
   npm run typecheck
   npm test
   npm run build
   ```

2. Update `CHECKLIST.md` to reflect completed and remaining work.
3. Update every section of `CURRENT.md`, including date, checkpoint, next
   actions, blockers, verification, and latest commit intent.
4. Finalize the active session log in `sessions/` with outcomes, decisions,
   verification, and exact handoff.
5. Synchronize any affected product, architecture, database, API, testing, or
   deployment documentation.
6. Review `git status` and the complete diff. Include all intended code,
   documentation, migrations, fixtures, and tracking files; exclude secrets,
   generated output, and unrelated local files.
7. Create one meaningful commit describing the checkpoint.
8. Push the current branch to its configured GitHub upstream before deploying.
9. Confirm the linked Supabase project matches `CURRENT.md`, run a migration
   dry-run, and apply only the reviewed pending migrations.
10. Confirm the linked Vercel project and required environment configuration,
    create a production deployment from the committed working tree, and verify
    the production URL.
11. Update `CURRENT.md` and the active session log with the GitHub commit,
    hosted migration state, production deployment, and exact next action.
12. Commit and push any final tracking-only update so GitHub is canonical.
13. Confirm the resulting commit SHA, synchronized upstream, clean working
    tree, applied migration history, and healthy production deployment.

If GitHub, Supabase, or Vercel authentication, targets, environment values, or
verification are unavailable, complete every safe prior step, record and
report the exact blocker, and do not pretend the closeout is finished.

## Rules

- Never store credentials, ESPN cookies, tokens, or private auth data here.
- Use ISO dates (`YYYY-MM-DD`) and sequential four-digit session numbers.
- Do not rewrite completed session history except to correct a factual error;
  annotate the correction.
- `CURRENT.md` must remain short enough to understand in two minutes.
