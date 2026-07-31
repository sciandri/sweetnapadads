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
SMS recipients and performs no external message delivery.
