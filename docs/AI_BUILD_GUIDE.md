# AI build guide

Before changing the project:

1. Read `tracking/CURRENT.md` and `tracking/CHECKLIST.md`.
2. Read `SweetLookingNapaDads_Project_Foundation.md`.
3. Read `AGENTS.md`.
4. Read the documentation for the affected subsystem.
5. Inspect existing tests and migrations.

During implementation:

- keep domain rules explicit and testable;
- do not hardcode season configuration;
- keep secrets and service-role access server-only;
- update docs and ADRs when decisions change;
- preserve historical and financial auditability.

Before handoff, run all commands in `docs/TESTING.md` and report any known
limitation with concrete impact.

When the user says “update and track,” follow `tracking/README.md` completely,
including the intentional commit and push.
