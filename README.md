# Sweet Looking Napa Dads

The permanent home of the Sweet Looking Napa Dads fantasy football league:
competition, finances, history, commissioner operations, and league lore.

## Status

Phase 0 is complete. Phase 1 is in progress with a reproducible local Supabase
stack and the first tested platform migration.

## Stack

- Next.js 16 App Router and React 19
- TypeScript and Tailwind CSS
- Supabase PostgreSQL, Auth, and Row Level Security
- Vitest and Playwright
- Vercel and GitHub Actions

## Local development

Requirements: Node.js 24+, npm 11+, and Docker Desktop for the local database.

```bash
npm install
cp .env.example .env.local
npm run dev
```

Fill in the Supabase publishable key in `.env.local` before using authenticated
routes. Never place the service-role key in a `NEXT_PUBLIC_` variable.

Open `http://localhost:3000`.

Start the local Supabase services in a separate terminal:

```bash
npm run db:start
npm run db:reset
```

Supabase Studio is available at `http://localhost:54323`. Run
`npm run db:stop` when the database stack is no longer needed.

## Quality checks

```bash
npm run lint
npm run typecheck
npm test
npm run db:lint
npm run db:test
npm run build
```

## Documentation

Start with [the product vision](docs/PRODUCT_VISION.md), then read
[architecture](docs/ARCHITECTURE.md) and the
[implementation plan](docs/IMPLEMENTATION_PLAN.md).

Every work session starts from
[the canonical project state](tracking/CURRENT.md). See
[the tracking protocol](tracking/README.md) for the “update and track”
closeout ritual.

The original workbook and project briefs remain in the repository as source
material until the 2025 import has been reconciled.
