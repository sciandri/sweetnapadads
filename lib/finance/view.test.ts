import { describe, expect, it } from "vitest";

import {
  buildTeamBalanceRows,
  buildTeamLedger,
  summarizeTeamBalances,
} from "./view";

describe("member finance view", () => {
  it("labels canonical team-perspective balances and orders money owed to the league first", () => {
    const rows = buildTeamBalanceRows(
      [
        { season_team_id: "b", team_obligations_cents: 0, payments_from_team_cents: 0, league_obligations_cents: 5000, payments_to_team_cents: 0, balance_increases_cents: 0, balance_decreases_cents: 0, balance_cents: -5000 },
        { season_team_id: "a", team_obligations_cents: 20000, payments_from_team_cents: 5000, league_obligations_cents: 0, payments_to_team_cents: 0, balance_increases_cents: 0, balance_decreases_cents: 0, balance_cents: 15000 },
        { season_team_id: "c", team_obligations_cents: 10000, payments_from_team_cents: 10000, league_obligations_cents: 0, payments_to_team_cents: 0, balance_increases_cents: 0, balance_decreases_cents: 0, balance_cents: 0 },
      ],
      [
        { id: "a", name: "Alpha", abbreviation: "ALP" },
        { id: "b", name: "Bravo", abbreviation: null },
        { id: "c", name: "Charlie", abbreviation: "CHR" },
      ],
    );

    expect(rows.map(({ team_name, status }) => [team_name, status])).toEqual([
      ["Alpha", "owes_league"],
      ["Charlie", "settled"],
      ["Bravo", "league_owes_team"],
    ]);
    expect(summarizeTeamBalances(rows)).toEqual({
      teams_owe_cents: 15000,
      league_owes_cents: 5000,
      settled_teams: 1,
    });
  });

  it("joins immutable events to canonical reconciliation without deriving balances", () => {
    const entries = buildTeamLedger(
      "team-a",
      [{ id: "obligation", season_team_id: "team-a", direction: "team_owes_league", amount_cents: 20000, category: "league_dues", description: "League dues", occurred_on: "2026-08-01" }],
      [{ obligation_id: "obligation", allocated_cents: 5000, outstanding_cents: 15000, reconciliation_status: "partial" }],
      [{ id: "payment", season_team_id: "team-a", direction: "from_team", amount_cents: 5000, paid_on: "2026-08-02", method: "venmo", note: null }],
      [{ payment_id: "payment", allocated_cents: 5000, unallocated_cents: 0, reconciliation_status: "allocated" }],
      [{ id: "adjustment", season_team_id: "team-a", direction: "decrease_team_balance", amount_cents: 1000, reason: "Commissioner correction", occurred_on: "2026-08-03" }],
    );

    expect(entries.map((entry) => entry.kind)).toEqual([
      "adjustment",
      "payment",
      "obligation",
    ]);
    expect(entries[1]).toMatchObject({
      reconciliation_status: "allocated",
      remainder_cents: 0,
    });
    expect(entries[2]).toMatchObject({
      reconciliation_status: "partial",
      remainder_cents: 15000,
    });
  });

  it("keeps one team's ledger isolated from other league events", () => {
    const entries = buildTeamLedger(
      "team-a",
      [{ id: "other", season_team_id: "team-b", direction: "team_owes_league", amount_cents: 100, category: "penalty", description: "Other team", occurred_on: "2026-08-01" }],
      [],
      [],
      [],
      [],
    );

    expect(entries).toEqual([]);
  });
});
