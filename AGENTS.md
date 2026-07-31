<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# Sweet Looking Napa Dads

Read `SweetLookingNapaDads_Project_Foundation.md` before making product or
architecture changes. It is the project source of truth.

At the beginning of every session, read `tracking/CURRENT.md` and
`tracking/CHECKLIST.md`. `tracking/CURRENT.md` is the canonical pickup point.

## Engineering rules

- Keep season rules in data, never in application constants.
- Store money as integer cents and perform financial calculations
  deterministically.
- Treat obligations and payments as separate financial events.
- Preserve raw ESPN payloads and make synchronization idempotent.
- Apply authorization in PostgreSQL Row Level Security, not only in UI code.
- Prefer Server Components; add Client Components only for interaction.
- Update relevant documentation and tests with every behavior change.
- Record consequential architecture changes in `docs/adr/`.

## Required checks

Run these before handing off a meaningful change:

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

## “Update and track” closeout

When the user says **update and track**, perform the complete ritual in
`tracking/README.md`: verify the project, update the canonical state and
checklist, append/finalize the session log, synchronize affected docs, review
the full diff, commit all intended repository changes, and push the current
branch. Do not perform the commit-and-push closeout unless the user invokes
that phrase or explicitly asks for it.
