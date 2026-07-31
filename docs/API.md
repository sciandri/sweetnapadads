# API

The application prefers Server Components for reads and Route Handlers for
mutations, integrations, and automation.

Planned server boundaries:

- `POST /api/sync/espn`: protected scheduled or commissioner sync
- `POST /api/admin/results`: validated manual-results fallback
- `POST /api/admin/payments`: record a payment or disbursement
- `POST /api/admin/adjustments`: append an audited correction
- `POST /api/admin/seasons`: create and configure a season

All handlers:

1. authenticate the caller;
2. authorize against league membership and role;
3. validate input at the boundary;
4. call domain and data-access services;
5. return stable error codes without exposing secrets.

The sync endpoint additionally accepts an automation secret and an idempotency
key. Public client code never receives service-role or ESPN credentials.
