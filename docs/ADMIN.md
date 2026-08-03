# Commissioner administration

Commissioner tools are operational controls, not direct table editors.

Initial capabilities:

- create and activate seasons;
- configure rules and payout schedules;
- manage teams, owners, and memberships;
- map ESPN teams;
- trigger and inspect synchronization;
- enter results manually when ESPN is unavailable;
- record payments and audited adjustments;
- enter playoff placement;
- publish announcements and media.
- generate, review, edit, and copy league-message drafts using verified ESPN
  and competition context.

Every payout and penalty must be commissioner-configurable for its season
before automation is enabled. This includes weekly high/low rules, placement
payouts, season awards, and any future penalty category. Configuration changes
must be audited; application code never supplies a fallback dollar amount.

The responsive season financial-rule editor is implemented at
`/dashboard/admin/season-rules`. It replaces the selected season's complete
enabled schedule as one batch. Weekly high/low rules are required; commissioners
can add or remove placement payouts, season awards, and general penalties.
Dollar inputs become integer cents at the request boundary, placement ranks and
stable keys must be unique, and every accepted save creates an immutable audit
snapshot. Saving configuration does not create an obligation or record a
payment.

The responsive ESPN control room is implemented at `/dashboard/admin/espn`.
It shows every active season team, saves a complete mapping batch, triggers the
protected competition endpoint, and displays recent run status. Mapping changes
cross a commissioner-only PostgreSQL function, replace the full active set
atomically, and preserve actor, timestamp, season, league, and accepted mapping
evidence. Production credentials and scheduling remain deliberately disabled.

The responsive missing-week fallback is implemented at
`/dashboard/admin/results`. A commissioner selects a season and week, pairs
every active team exactly once, enters scores to the hundredth, and supplies a
required reason. The save is one locked database transaction: it records an
immutable audit batch, reciprocal results, and any uniquely determined
configured weekly awards and obligations. The form derives its pair count from
active season teams, so ten- and twelve-team seasons use the same workflow.

Missing-week mode deliberately refuses a week with any accepted matchup.
Correction mode writes a new immutable evidence batch over one complete
accepted week. The latest correction becomes the accepted projection without
changing the original ESPN, import, or manual rows. When high/low awards move or
disappear, append-only adjustments neutralize displaced obligations and the
replacement awards receive configured obligations. Exact retries are safe and
changed retries fail closed.

The MVP commissioner area now includes ESPN mapping and sync, complete season
financial-rule configuration, missing/corrected result control, in-app
notifications, and AI-assisted message drafting. Lower-frequency season,
membership, payment, and playoff data entry remains an intentional future
expansion rather than an unaudited generic table editor.

Every consequential action records actor, timestamp, league, season, and a
human-readable reason where appropriate. Destructive historical deletion is
not exposed through the application.

Historical imports are commissioner-only review workflows. The source workbook
is first staged losslessly, then team aliases, event labels, and discrepancies
are resolved. Approval is unavailable while a blocking issue or pending
mapping remains. Approval and normalized-history commit are separate actions.

AI message generation is also commissioner-only. The generator receives a
bounded fact package assembled by the server. ESPN determines standings order;
the model may summarize it but cannot recompute it. The application records no
SMS recipients and performs no external message delivery. The Responses API
call uses strict structured output for exactly three drafts, disables provider
response storage, and fails with a stable configuration response until the
server-only OpenAI key is present.
