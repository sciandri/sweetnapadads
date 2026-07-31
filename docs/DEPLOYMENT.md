# Deployment

## Targets

- Web application: Vercel
- Database and authentication: Supabase
- Scheduled ESPN sync: GitHub Actions calling a protected production endpoint

## Provisioned projects

- Vercel: `sciandri/sweetnapadads`
  (`prj_qNC8JhIZiZfvqlLPU66PYtlrwn7w`)
- Supabase: `sweetnapadads` (`cleyfpzxckjtmsoesgby`, `us-west-2`)

The repository is linked locally to both projects. Release closeout commit
`bdc4cc2` is deployed to Vercel production as
`dpl_ENTbaLv63W9QivU7QjFUGKF3XMPY`. All seven versioned migrations through
`20260731090000` are applied to hosted Supabase.

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

`OPENAI_API_KEY` is a future server-only requirement for live commissioner
message generation. It is not currently configured, must never use a
`NEXT_PUBLIC_` prefix, and must be stored only in Vercel environment secrets.
Until it is configured and the reviewed generation Route Handler is enabled,
the composer remains an honest preview: commissioners can inspect the bounded
fact package, write or paste a draft, and copy it, but cannot request AI output.
The application does not store phone numbers or send SMS messages.

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

Items 1–4 are configured in production. Production SMTP and real-member Auth
smoke tests remain intentionally pending; do not invite real members before
SMTP is configured.

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
