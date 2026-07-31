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
events, content, and import reconciliation.

## Interaction principles

- Show a balance with its components and source events.
- Make season context persistent and unmistakable.
- Use color as reinforcement, never the only status indicator.
- Treat mobile as a primary league-checking experience.
- Design from a 320px minimum viewport upward, with stacked mobile sections,
  touch-safe spacing, fluid type, and no horizontal overflow.
- Keep dense tables accessible with labels, filters, and useful empty states.
- Separate confirmed facts, pending sync issues, and commissioner overrides.

The initial landing page establishes the visual language; authenticated
application shells arrive with the auth milestone.
