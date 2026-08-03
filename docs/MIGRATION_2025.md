# 2025 workbook migration

The workbook is source evidence, not a normalized database export. Import uses
staging tables, explicit mapping, a preview, reconciliation reports, and a
separate commit step.

## Source contract

The canonical source is `Sweet Looking Napa Dads.xlsx`. Its immutable checksum,
sheet inventory, observed ranges, and issue evidence live in
`data/import/2025/workbook-manifest.json`. A unit test verifies the workbook
size and SHA-256 checksum on every application test run.

`data/import/2025/decision-queue.json` converts every finding into explicit
commissioner options. On 2026-07-30 the commissioner approved all seven
recommended treatments. The source workbook remains unchanged.

`data/import/2025/normalized-preview.json` is the checksum-pinned, review-only
normalization result. It contains stable source keys, row-level references,
160 results, 14 derived weekly awards, 49 obligations, 43 payments, 43
deterministic allocations, and one external cash event. The artifact remains
review-only until the approved batch is passed to the domain commit RPC.

The workbook contains eight sheets:

- `Teams`: 10 team/owner rows;
- `League Ledger`: 75 financial evidence rows;
- `Team Balance`: 10 derived team summaries;
- `Weekly Results`: 160 team results plus 16 week-label rows;
- `Weekly Awards`: award formulas and helper ranges;
- `League Payouts`: season and placement payout configuration;
- `Net Cash`: derived cash and balance checks;
- `Bets`: two side-bet records.

## Review boundary

`historical_import_batches` owns a source hash and review lifecycle.
`historical_import_rows` preserves every source row and formula payload without
deduplicating identical evidence. Team aliases and ledger `Type + How`
combinations are resolved through explicit mapping tables so weekly, season,
and placement events cannot collapse into one category. Findings live in
`historical_import_issues`, and the
`historical_import_batch_review` view reports whether a batch is ready for
approval.

Only commissioners can inspect or modify staging data. Raw rows are immutable.
Mappings and findings freeze after approval. A batch cannot be approved until:

- at least one source row is staged;
- every team identifier is mapped or deliberately ignored;
- every event label is mapped or deliberately ignored;
- no blocking issue remains open.

Approval does not itself normalize or publish history. The later commit step
must create immutable domain events from the approved preview and preserve
source-row provenance.

## Approved findings

- champion payout configuration says $720, while ledger events record a $760
  obligation and a $660 payment;
- `League Ledger!C2` contains malformed Excel serial `374603`;
- `Team Balance!T2:T11` contains ten `#NAME?` results;
- weekly award helper ranges contain formula and layout inconsistencies;
- team-name capitalization, abbreviations, and spelling vary in side bets;
- Napa Kojak assessments in ledger rows 46 and 58 share the week-9 date even
  though their sequence matches the week-9 and week-12 low-score results;
- ledger labels require explicit obligation/payment semantics and stable
  provenance.

No discrepancy is silently corrected. Each approved treatment is preserved in
the decision queue and reflected in preview provenance.

## Accepted treatment

The commissioner approved:

- use the formula-backed $720 champion obligation, retain the actual $660
  payment, and leave $60 owed unless the commissioner explicitly forgives it;
- correct the malformed 2925 date to `2025-08-16`;
- derive “last method” from normalized payments instead of importing broken
  formula outputs;
- derive weeks 1–14 awards from weekly results and season rules;
- approve the four unambiguous side-bet team aliases;
- keep both Napa Kojak penalty obligations and correct row 58 to
  `2025-11-24`;
- map ledger events by `Type + How` so each obligation and payment retains its
  correct semantics.

The normalized preview therefore uses a $720 champion obligation, the actual
$660 payment, and a $60 league payable. The source $760 row remains
superseded evidence.

## Preview reconciliation

All amounts are integer cents:

- team obligations: `$2,980`;
- payments received from teams: `$2,710`;
- league payout obligations: `$2,000`;
- payments made to teams: `$1,770`;
- net team balance: `$40` owed to the league;
- external draft-party expense: `$700`;
- realized league cash: `$240`.

Every imported payment is fully allocated. Weekly payouts total `$700`, weekly
penalties total `$280`, and configured payout obligations total `$2,000`.

The workbook identifies the external expense amount but not its exact date or
counterparty. The preview preserves those fields as unknown rather than
inventing values; the amount is sufficient for cash reconciliation.

## Commit boundary

Approval and preview generation do not write normalized domain rows.
`commit_historical_import(batch_id, normalized_preview)` is the only domain
commit boundary. It:

- requires an authenticated active commissioner and an approved batch;
- verifies the source hash, season, approval decision, commit gate, and every
  preview team mapping;
- creates matchups, weekly results, linked awards, obligations, payments,
  allocations, and external cash events in one transaction;
- recomputes team, payment-allocation, and league-cash reconciliation before
  changing the batch to `committed`;
- preserves the exact normalized preview plus a provenance row for every
  committed domain record;
- returns `already_committed` for an exact retry and rejects a changed retry.

Any validation failure rolls back every domain and provenance write and leaves
the batch approved. The canonical 2025 artifact still requires a staged 2025
league/season with all ten team mappings before this RPC can be invoked.

## Local canonical rehearsal

`data/import/2025/workbook-rows.json` preserves all 533 rows inside the eight
manifest ranges, including headers, blank layout rows, cached values, and exact
formulas. Every row has its own SHA-256 digest, and the extraction remains tied
to the immutable workbook checksum.

The local-only operational rehearsal is:

```bash
npm run db:reset
npm run import:2025:rehearse
```

The runner refuses any non-local Supabase URL. It creates a canonical local
2025 season, stages all source rows, ten team mappings, eighteen approved
`Type + How` mappings, and seven resolved findings, then authenticates as the
synthetic commissioner and invokes `commit_historical_import`. It verifies the
stored record counts and full reconciliation before making an exact retry.

The verified rehearsal produced 80 matchups, 160 weekly results, 14 weekly
awards, 49 obligations, 43 payments, 43 allocations, and one external cash
event. The result reconciled to a `$40` net team balance and `$240` realized
league cash balance. A second full runner invocation without a reset returned
`already_committed` and created no duplicates.

The commissioner explicitly approved the hosted production commit on
2026-08-02 after reviewing those counts and reconciliation totals. Production
preserves all 533 rows, the approved mappings and issues, the exact committed
preview, 390 domain provenance links, and the expected domain counts above.

## Commissioner-confirmed closing correction

On 2026-08-03, the commissioner clarified that the final 2025 closing state
was zero league cash and a zero balance for every team. The imported source
evidence remains unchanged. The Excel `Team Balance` sheet reports zero for
all ten teams, while `Net Cash` reports `$240` realized league cash. The
approved normalized import used the configured `$720` champion obligation in
place of the ledger's `$760` obligation and therefore left Los Pollos Hermanos
II at a `$40` team-perspective balance. Production appends two audited manual
corrections instead of rewriting those records:

- a `$40` `decrease_team_balance` adjustment settles Los Pollos Hermanos II;
- a `$240` `closing_reconciliation` cash-out settles the season cash account.

Both records use stable source keys, identify the commissioner, and use
2026-08-03 as the correction-recording date. The canonical production views
now return `$0` for all ten team balances and `$0` for 2025 league cash.
The team correction agrees with Excel's closing team balances. The cash
correction reflects the commissioner's later real-world instruction and not
the workbook's `$240` realized-cash output.

The two `Bets` rows were preserved in the original raw evidence and alias
review but were not domain records in the original commit preview. The release
therefore adds a separate immutable `side_bets` model and normalizes both `$20`
records with their two structured parties, exact descriptions, source rows,
and import-batch link. No outcome, settlement, or event date is invented.
