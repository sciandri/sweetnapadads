import { describe, expect, it } from "vitest";

import { buildOwnershipHistory, buildTeamSeasonHistory } from "./history";

describe("team history view", () => {
  it("summarizes accepted reciprocal results without inventing official rank", () => {
    const history = buildTeamSeasonHistory(
      "team-a",
      [{ id: "season", year: 2026, name: "2026 Season", status: "active" }],
      [{ id: "entry-a", team_id: "team-a", season_id: "season", name: "Alpha 2026", abbreviation: "ALP" }],
      [
        { matchup_id: "m1", season_id: "season", season_team_id: "entry-a", opponent_season_team_id: "entry-b", score: 105.25, result: "win" },
        { matchup_id: "m1", season_id: "season", season_team_id: "entry-b", opponent_season_team_id: "entry-a", score: 99.5, result: "loss" },
        { matchup_id: "m2", season_id: "season", season_team_id: "entry-a", opponent_season_team_id: "entry-c", score: 80, result: "tie" },
        { matchup_id: "m2", season_id: "season", season_team_id: "entry-c", opponent_season_team_id: "entry-a", score: 80, result: "tie" },
      ],
      [{ season_id: "season", high_score_season_team_id: "entry-a", low_score_season_team_id: "entry-c" }],
      [{ season_id: "season", season_team_id: "entry-a", balance_cents: -5000 }],
    );

    expect(history).toEqual([expect.objectContaining({
      games: 2,
      wins: 1,
      losses: 0,
      ties: 1,
      points_for: 185.25,
      points_against: 179.5,
      high_score_honors: 1,
      low_score_penalties: 0,
      balance_cents: -5000,
    })]);
    expect(history[0]).not.toHaveProperty("official_rank");
  });

  it("orders franchise seasons newest first and keeps empty seasons honest", () => {
    const history = buildTeamSeasonHistory(
      "team-a",
      [
        { id: "old", year: 2025, name: "2025", status: "complete" },
        { id: "new", year: 2026, name: "2026", status: "setup" },
      ],
      [
        { id: "old-entry", team_id: "team-a", season_id: "old", name: "Old Alpha", abbreviation: null },
        { id: "new-entry", team_id: "team-a", season_id: "new", name: "New Alpha", abbreviation: null },
      ],
      [],
      [],
      [],
    );

    expect(history.map(({ year, games }) => [year, games])).toEqual([[2026, 0], [2025, 0]]);
  });

  it("shows current ownership first and resolves historical owner labels", () => {
    const rows = buildOwnershipHistory(
      [
        { id: "old", owner_id: "owner-a", started_on: "2020-01-01", ended_on: "2024-12-31", is_primary: true },
        { id: "current", owner_id: "owner-b", started_on: "2025-01-01", ended_on: null, is_primary: true },
      ],
      [
        { id: "owner-a", display_name: "Original Dad" },
        { id: "owner-b", display_name: "Current Dad" },
      ],
    );

    expect(rows.map((row) => row.owner_name)).toEqual(["Current Dad", "Original Dad"]);
  });
});
