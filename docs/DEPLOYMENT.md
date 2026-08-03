# Deployment

## Targets

- Web application: Vercel
- Database and authentication: Supabase
- ESPN sync operations: protected manual and in-season scheduled GitHub Actions
  calling one production endpoint

## Provisioned projects

- Vercel: `sciandri/sweetnapadads`
  (`prj_qNC8JhIZiZfvqlLPU66PYtlrwn7w`)
- Supabase: `sweetnapadads` (`cleyfpzxckjtmsoesgby`, `us-west-2`)

The repository is linked locally to both projects. Source checkpoint `7624f5d`
is deployed to Vercel production as
`dpl_9UgX2X1eWDmSkBoJCBrTjtE2C7YM`. All sixteen versioned migrations through
`20260731180000` are applied to hosted Supabase.

## Environments

Development and production use separate Supabase projects and credentials.
Preview deployments must never use production service-role or ESPN secrets.

Required environment variables are documented in `.env.example`. Values are
configured directly in the hosting providers and never committed.

`NEXT_PUBLIC_SUPABASE_URL` and
`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` are intentionally available to the
browser and are safe only in combination with complete RLS. The
`SUPABASE_SERVICE_ROLE_KEY` bypasses RLS and must be configured only as a
server-side secret. Supabase clients are constructed per request so Vercel
instances cannot share user sessions through module state.

The production Vercel project has the service-role value configured for
server-only use. Preview and development scopes intentionally do not inherit
it. No browser bundle or `NEXT_PUBLIC_` variable may expose this credential.

`SITE_URL` is the canonical HTTP(S) application origin used to construct Auth
callbacks. Production must use `https://sweetnapadads.com`; local development
uses `http://localhost:3000`.

`OPENAI_API_KEY` is the server-only requirement for live commissioner message
generation. It is not currently configured, must never use a `NEXT_PUBLIC_`
prefix, and must be stored only in Vercel environment secrets. The reviewed
Route Handler is implemented and returns `generation_not_configured` until the
key is present. `OPENAI_MODEL` is an optional server-only override; the default
is `gpt-5.6-terra`. The application does not store phone numbers or send SMS
messages.

`ESPN_LEAGUE_ID`, `ESPN_S2`, `ESPN_SWID`, and `SYNC_SECRET` are required to
enable scheduled production standings synchronization. All are server-only.
The protected endpoint is safe to deploy without them and returns a stable
configuration or authorization failure; do not configure or schedule it until
season-team mappings have been reviewed in the commissioner control room.

`.github/workflows/espn-standings-sync.yml` is a production workflow protected
by the GitHub `production` environment. It requires repository variables
`SITE_URL` and `SEASON_ID` plus Actions secret `SYNC_SECRET`, validates a
canonical season UUID, uses evidence-derived idempotency, and emits only the
stable response summary. It retains manual dispatch and runs Tuesdays at 16:00
UTC from September through January. Follow the
[ESPN standings runbook](runbooks/ESPN_STANDINGS_SYNC.md) before configuring
secrets, running it, rotating credentials, or proposing a schedule.

Before releasing authentication:

1. Keep the Supabase email provider enabled and public user signup disabled.
2. Set the Supabase Auth Site URL to `https://sweetnapadads.com`.
3. Allow the exact production callback URL
   `https://sweetnapadads.com/auth/callback`.
4. Configure the Vercel production `SITE_URL`.
5. Configure production SMTP before inviting real members; Supabase's default
   mail service is for limited trial use.
6. Smoke-test an invited member, an expired link, and an authenticated
   non-member.

All six items are configured in production. Supabase Auth uses custom Resend
SMTP from `login@auth.sweetnapadads.com`; the first commissioner invitation was
accepted and the authenticated membership path was verified. The production
league and a neutral 2026 setup season exist so member and commissioner routes
have valid league context. The 2026 financial placeholders remain zero until
the commissioner accepts the actual season rule schedule.

The Resend credential used for the first smoke test must be rotated before
inviting additional members because its value became visible in the operator
verification transcript. Store only the replacement credential in Supabase;
never copy it into the repository or tracking records.

## Release gate

1. CI checks pass.
2. Database migrations have been tested locally.
3. Production migration is applied.
4. Application is deployed.
5. Health, authentication, and RLS smoke tests pass.
6. Scheduled sync secret is verified without logging it.

Rollback favors application rollback plus forward database remediation;
destructive down migrations are avoided once production data exists.

The phrase “update and track” authorizes the release sequence after all quality
gates pass: push the reviewed checkpoint to GitHub, apply the reviewed pending
Supabase migrations, deploy the committed tree to Vercel production, verify
both targets, and push the final tracking record.
