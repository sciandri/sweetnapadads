import { describe, expect, it } from "vitest";

import { buildCompetitionActivity, buildFinancialActivity } from "./view";

const teams = [{ id: "a", name: "Alpha" }, { id: "b", name: "Bravo" }];

describe("league activity view", () => {
  it("keeps stored weekly honors distinct from accepted matchup results", () => {
    const entries = buildCompetitionActivity(
      [{ id: "m1", week: 2, phase: "regular_season", source_type: "espn" }],
      [
        { matchup_id: "m1", season_team_id: "a", score: 110, result: "win" },
        { matchup_id: "m1", season_team_id: "b", score: 90, result: "loss" },
      ],
      [{ id: "award", week: 2, high_score_season_team_id: "a", high_score: 110, low_score_season_team_id: "b", low_score: 90, source_type: "system" }],
      teams,
    );

    expect(entries.map((entry) => entry.kind)).toEqual(["award", "matchup"]);
    expect(entries[0].source).toBe("system");
    expect(entries[1]).toMatchObject({ headline: "Alpha defeated Bravo", detail: "110.00 – 90.00" });
  });

  it("renders tied and incomplete matchups honestly", () => {
    const entries = buildCompetitionActivity(
      [
        { id: "tie", week: 3, phase: "regular_season", source_type: "manual" },
        { id: "pending", week: 4, phase: "postseason", source_type: "manual" },
      ],
      [
        { matchup_id: "tie", season_team_id: "a", score: 100, result: "tie" },
        { matchup_id: "tie", season_team_id: "b", score: 100, result: "tie" },
      ],
      [],
      teams,
    );

    expect(entries[0].headline).toBe("Matchup result pending");
    expect(entries[1].headline).toBe("Alpha tied Bravo");
  });

  it("orders immutable financial events by their own dates without merging them into competition", () => {
    const entries = buildFinancialActivity(
      [{ id: "o", season_team_id: "a", direction: "team_owes_league", amount_cents: 20000, description: "League dues", occurred_on: "2026-08-01" }],
      [{ id: "p", season_team_id: "a", direction: "from_team", amount_cents: 5000, paid_on: "2026-08-02", note: null }],
      [{ id: "x", season_team_id: "a", direction: "decrease_team_balance", amount_cents: 1000, reason: "Correction", occurred_on: "2026-08-03" }],
      teams,
    );

    expect(entries.map((entry) => entry.kind)).toEqual(["adjustment", "payment", "obligation"]);
    expect(entries[1]).toMatchObject({ team_name: "Alpha", direction: "Paid by team" });
  });
});
