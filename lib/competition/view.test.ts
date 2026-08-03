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
      [],
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
      [{
        week: 3,
        high_score_season_team_id: "team-c",
        high_score: 155.12,
        high_score_obligation_id: "high-obligation",
        low_score_season_team_id: "team-d",
        low_score: 72,
        low_score_obligation_id: "low-obligation",
        source_type: "system",
      }],
      teams,
      [
        { id: "high-obligation", direction: "league_owes_team", amount_cents: 5000, description: "Week 3 high score payout" },
        { id: "low-obligation", direction: "team_owes_league", amount_cents: 2000, description: "Week 3 low score penalty" },
      ],
    );

    expect(week.award).toEqual({
      source_type: "system",
      high: {
        team_name: "Charlie Dads",
        score: 155.12,
        obligation: { id: "high-obligation", direction: "league_owes_team", amount_cents: 5000, description: "Week 3 high score payout" },
      },
      low: {
        team_name: "Delta Dads",
        score: 72,
        obligation: { id: "low-obligation", direction: "team_owes_league", amount_cents: 2000, description: "Week 3 low score penalty" },
      },
    });
  });

  it("keeps an award visible when its financial effect is unavailable", () => {
    const [week] = buildCompetitionWeeks(
      [{ id: "match-1", week: 4, phase: "regular_season", source_type: "import" }],
      [],
      [{
        week: 4,
        high_score_season_team_id: "team-a",
        high_score: 140,
        high_score_obligation_id: "missing-high",
        low_score_season_team_id: "team-b",
        low_score: 80,
        low_score_obligation_id: "missing-low",
        source_type: "import",
      }],
      teams,
      [],
    );

    expect(week.award?.high.obligation).toBeNull();
    expect(week.award?.low.obligation).toBeNull();
  });

  it("formats accepted fantasy scores without losing hundredths", () => {
    expect(formatCompetitionScore(123.5)).toBe("123.50");
    expect(formatCompetitionScore(1234.56)).toBe("1,234.56");
  });
});
