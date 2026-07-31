import { describe, expect, it } from "vitest";

import { buildCompetitionWeeks, formatCompetitionScore } from "./view";

const teams = [
  { id: "team-a", name: "Alpha Dads", abbreviation: "ALP" },
  { id: "team-b", name: "Bravo Dads", abbreviation: "BRV" },
  { id: "team-c", name: "Charlie Dads", abbreviation: null },
  { id: "team-d", name: "Delta Dads", abbreviation: "DLT" },
];

describe("member competition view", () => {
  it("groups reciprocal results by week and puts the winner first", () => {
    const weeks = buildCompetitionWeeks(
      [
        { id: "match-1", week: 2, phase: "regular_season", source_type: "espn" },
        { id: "match-2", week: 1, phase: "regular_season", source_type: "espn" },
      ],
      [
        { matchup_id: "match-1", season_team_id: "team-a", opponent_season_team_id: "team-b", score: 99.25, result: "loss" },
        { matchup_id: "match-1", season_team_id: "team-b", opponent_season_team_id: "team-a", score: 101.5, result: "win" },
      ],
      [],
      teams,
    );

    expect(weeks.map((week) => week.week)).toEqual([2, 1]);
    expect(weeks[0].matchups[0].results.map((result) => result.team_name)).toEqual([
      "Bravo Dads",
      "Alpha Dads",
    ]);
    expect(weeks[0].matchups[0].complete).toBe(true);
    expect(weeks[1].matchups[0].complete).toBe(false);
  });

  it("links high and low award labels without recomputing them", () => {
    const [week] = buildCompetitionWeeks(
      [{ id: "match-1", week: 3, phase: "regular_season", source_type: "system" }],
      [],
      [{ week: 3, high_score_season_team_id: "team-c", high_score: 155.12, low_score_season_team_id: "team-d", low_score: 72 }],
      teams,
    );

    expect(week.award).toEqual({
      high: { team_name: "Charlie Dads", score: 155.12 },
      low: { team_name: "Delta Dads", score: 72 },
    });
  });

  it("formats accepted fantasy scores without losing hundredths", () => {
    expect(formatCompetitionScore(123.5)).toBe("123.50");
    expect(formatCompetitionScore(1234.56)).toBe("1,234.56");
  });
});
