# 2025 workbook migration

The workbook is source evidence, not a normalized database export. Import uses
staging tables, explicit mapping, a preview, reconciliation reports, and a
separate commit step.

Known issues to resolve:

- champion payout configuration says $720, while ledger events record a $760
  obligation and a $660 payment;
- one ledger date appears malformed;
- the “Last Method” workbook formula currently produces `#NAME?`;
- weekly award helper ranges contain formula and layout inconsistencies;
- team-name capitalization and abbreviations vary in side bets;
- obligations represented only as ledger labels need stable rule provenance.

No discrepancy is silently corrected. Each receives an accepted mapping,
commissioner decision, or documented adjustment. The committed import must
reconcile to approved team balances, league cash, award totals, and payout
totals.
