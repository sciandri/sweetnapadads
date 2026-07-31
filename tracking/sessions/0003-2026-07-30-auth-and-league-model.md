# Session 0003 — Platform Auth and league model

- Date: 2026-07-30 to 2026-07-31
- Status: complete — published and deployed
- Branch: `main`
- Starting commit: `eeede7e`
- Ending source commit: `c25a642`

## Goal

Finish the Phase 1 development seed and build an invite-only, passwordless
authentication flow with league authorization, then begin Phase 2 team and
ownership modeling.

## Starting context

Phase 1 schema, RLS, Auth helpers, hosted migrations, and production deployment
are complete. The first incomplete platform item is the local development seed.

## Work completed

- [x] Add a fixed synthetic commissioner Auth identity and triggered profile.
- [x] Add a development league with an active commissioner membership.
- [x] Add a 2026 development season and season-scoped financial rules.
- [x] Add a pgTAP seed contract and make the platform suite seed-aware.
- [x] Document the local seed identity and its intentionally non-login state.
- [x] Run the complete local database and application verification suite.
- [x] Add an invitation-only magic-link login action and responsive page.
- [x] Prevent public account creation and account enumeration.
- [x] Add PKCE and token-hash callback verification with safe return paths.
- [x] Add authenticated dashboard, membership authorization, access-denied,
      and sign-out states.
- [x] Add Auth flow and callback unit tests.
- [x] Verify unknown-user, expired-link, unauthenticated, and authorized-member
      paths in the local browser and Auth stack.
- [x] Correct local email-provider configuration while preserving the global
      signup prohibition.
- [x] Make the synthetic Auth fixture compatible with the Auth admin API.
- [x] Configure git-ignored local public Supabase and site URL values.
- [x] Integrate the supplied logo into the landing, login, access-denied, and
      authenticated shell states through a reusable responsive component.
- [x] Add durable teams and historical owner identities.
- [x] Add dated ownership history with one current primary owner.
- [x] Add season-specific team names, abbreviations, ESPN IDs, and status.
- [x] Enforce same-league relationships with composite foreign keys.
- [x] Add commissioner write, member read, outsider denial, and no-delete
      contracts for all team and ownership tables.
- [x] Extend the deterministic seed with a franchise and ownership chain.
- [x] Add immutable obligations, payments, allocation links, allocation
      reversals, and audited financial adjustments.
- [x] Enforce safe-integer cents, stable source keys, same-team event context,
      settlement direction compatibility, and allocation caps.
- [x] Add commissioner-write, member-read, outsider-denial, immutability, and
      correction-workflow pgTAP coverage.
- [x] Extend the deterministic seed with a partial buy-in payment, allocation,
      and reasoned adjustment.
- [x] Add canonical team balance, obligation reconciliation, and payment
      reconciliation views with security-invoker RLS behavior.
- [x] Verify exact accounting equations and allocation-reversal propagation.
- [x] Audit all eight 2025 workbook sheets without modifying the source.
- [x] Record the workbook checksum, observed ranges, and seven unresolved
      findings in a machine-checked source manifest.
- [x] Add lossless historical import batches and immutable raw row evidence.
- [x] Add explicit team-alias and financial-event mapping workflows.
- [x] Add structured issue decisions, approval gates, terminal review states,
      and commissioner-only import RLS.
- [x] Trace the seven workbook findings to exact cells and calculate their
      normalization impact.
- [x] Add a machine-checked decision queue with explicit options and
      recommendations while leaving every option unaccepted.
- [x] Refine financial mappings to use workbook `Type + How` so payout
      categories cannot collapse.
- [x] Record commissioner approval of all seven recommended workbook
      treatments.
- [x] Generate a checksum-pinned, review-only normalized 2025 preview with
      source references and deterministic allocations.
- [x] Reconcile the approved preview to `$40` net team balance and `$240`
      realized league cash.
- [x] Separate the `$700` external draft-party expense from team payments with
      an immutable external-cash event model and canonical cash view.
- [x] Run the complete application, security, database, build, and tracking
      release gates.
- [x] Commit and push source checkpoint `c25a642` to GitHub `main`.
- [x] Configure hosted Supabase Auth for the production site and callback URL.
- [x] Add Vercel production `SITE_URL`.
- [x] Dry-run and apply migrations `20260731050000` through
      `20260731090000` to hosted Supabase.
- [x] Deploy production as `dpl_DPkGYFhjWBHhVbgYPt1CT7wJex1j`.
- [x] Verify GitHub source, hosted migration history, Auth configuration,
      production aliases, home page, and invitation-only login page.

## Decisions

- Keep the seed local-only, deterministic, credential-free, and composed only
  of data insertions.
- Use a reserved `.test` email and fixed UUIDs so future fixtures can refer to
  the same synthetic records safely.
- Leave the commissioner without a password; login-capable development users
  belong to the Auth admin API or local Studio workflow.
- Use passwordless email links for invited members and pass
  `shouldCreateUser: false` on every public login request.
- Treat Proxy as session refresh only; protected pages verify claims and rely
  on PostgreSQL RLS for league authorization.
- Return generic magic-link responses so the login form cannot enumerate
  invited email addresses.
- Keep cash movements with non-team counterparties separate from team-scoped
  financial events; derive season cash from both ledgers.

## Verification

- `npm run lint`: passing
- `npm run tracking:check`: passing
- `npm run typecheck`: passing
- `npm test`: 25 passing
- `npm run build`: passing
- `npm run db:reset`: passing with migrations and seed
- `npm run db:lint`: passing with no warnings
- `npm run db:test`: 153 passing
- Local browser smoke test: magic-link email, callback exchange, verified
  claims, membership RLS, and commissioner dashboard passing
- `npm audit`: zero known vulnerabilities
- GitHub `main`: `c25a642`
- Hosted migration history: all seven local versions match remote
- Hosted Supabase Auth production config: up to date
- Vercel deployment `dpl_DPkGYFhjWBHhVbgYPt1CT7wJex1j`: Ready
- Production home and login: HTTP 200

## Risks or blockers

- Docker Desktop must be running for local database verification.
- The synthetic commissioner has no password and cannot exercise login flows.
- Production SMTP is not configured; do not invite real members until it is.
- The hosted schema has no synthetic development seed and no real league
  membership yet, by design.
- The service-role key remains absent from Vercel because no deployed feature
  requires it.

## Exact handoff

Start session 0004 from clean, synchronized `main`. Configure production SMTP
before inviting real members; otherwise implement the atomic, idempotent
domain commit for the approved, reconciled 2025 preview.
