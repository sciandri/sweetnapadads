# UI and experience

## Character

The visual language combines Napa club ephemera with a precise financial
report: warm paper, deep green, wine red, restrained gold, editorial serif
headlines, and compact monospace labels.

## Brand asset

`logo/sweetlookingnapadads.png` is the canonical and currently only supplied
brand asset. New interface work should preserve its football, Napa, and
dark-green/wine-red visual identity. Derivative icons or simplified marks must
remain recognizably related to it and must not replace the source file.

The original transparent PNG is now rendered directly through the shared
`BrandLogo` component on the landing page, authentication states, and member
shell. Compact placements keep nearby text labels because the full crest
lettering is not expected to carry navigation meaning at small sizes.

## Information architecture

Member navigation:

- Dashboard
- Standings
- Weekly results
- Awards
- Finances
- Teams
- Records
- Activity

Commissioners gain an Admin area for seasons, team mappings, syncs, ledger
events, content, import reconciliation, and an AI-assisted message composer.

## Interaction principles

- Show a balance with its components and source events.
- Make season context persistent and unmistakable.
- Use color as reinforcement, never the only status indicator.
- Treat mobile as a primary league-checking experience.
- Design from a 320px minimum viewport upward, with stacked mobile sections,
  touch-safe spacing, fluid type, and no horizontal overflow.
- Keep dense tables accessible with labels, filters, and useful empty states.
- Separate confirmed facts, pending sync issues, and commissioner overrides.

The member finance surface follows these principles with a league summary,
touch-safe team selector cards, a selected balance explanation, and a stacked
event ledger. Color reinforces—without replacing—explicit `owes league`,
`league owes team`, and `settled` labels. Actual cash is visually and verbally
separate from net obligations.

The team record book uses a responsive season directory and durable franchise
pages. Season cards retain historical team names, make ownership gaps explicit,
and place accepted record, points, honors, and balance in one scan. Links return
members to the underlying results and finance evidence.

The league activity surface places two parallel timelines side by side on wide
screens and stacks them on mobile. Competition is labeled and ordered by week;
financial events are labeled and ordered by date. Matchups, stored honors,
obligations, payments, and audited adjustments keep distinct visual labels,
with explicit empty states for either stream.

Side bets appear below those timelines as undated source cards. Each card shows
the two structured teams, exact description, and stake while explicitly
avoiding an inferred winner, settlement, or date.

## Commissioner message composer

The composer is optimized for copying into the league's existing group-text
thread. It includes:

- season and week selectors;
- explicit toggles for official standings, accepted results, and awards;
- a visible ESPN `last synced` timestamp and stale-data warning;
- commissioner notes, tone, and target-length controls;
- three editable draft options;
- a large mobile-safe copy button with a confirmation state; and
- a final fact summary beside the draft so the commissioner can verify it.

The interface never offers a send button, recipient list, phone-number field,
or delivery status. AI output is always a draft requiring human review.

The initial landing page establishes the visual language; authenticated
application shells arrive with the auth milestone.
