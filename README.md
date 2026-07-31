# Sweet Looking Napa Dads

The permanent home of the Sweet Looking Napa Dads fantasy football league:
competition, finances, history, commissioner operations, and league lore.

## Status

Phase 0 is in progress. The repository has a production-oriented Next.js
foundation, the initial visual language, test tooling, and architecture
documentation. Database and authentication work begins in Phase 1.

## Stack

- Next.js 16 App Router and React 19
- TypeScript and Tailwind CSS
- Supabase PostgreSQL, Auth, and Row Level Security
- Vitest and Playwright
- Vercel and GitHub Actions

## Local development

Requirements: Node.js 24+ and npm 11+.

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Quality checks

```bash
npm run lint
npm run typecheck
npm test
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
