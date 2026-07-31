# Deployment

## Targets

- Web application: Vercel
- Database and authentication: Supabase
- Scheduled ESPN sync: GitHub Actions calling a protected production endpoint

## Environments

Development and production use separate Supabase projects and credentials.
Preview deployments must never use production service-role or ESPN secrets.

Required environment variables are documented in `.env.example`. Values are
configured directly in the hosting providers and never committed.

## Release gate

1. CI checks pass.
2. Database migrations have been tested locally.
3. Production migration is applied.
4. Application is deployed.
5. Health, authentication, and RLS smoke tests pass.
6. Scheduled sync secret is verified without logging it.

Rollback favors application rollback plus forward database remediation;
destructive down migrations are avoided once production data exists.
