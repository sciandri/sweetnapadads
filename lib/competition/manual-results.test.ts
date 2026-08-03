import { describe, expect, it } from "vitest";

import { parseManualResultsRequest } from "./manual-results";

const seasonId = "11111111-1111-4111-8111-111111111111";
const homeId = "22222222-2222-4222-8222-222222222222";
const awayId = "33333333-3333-4333-8333-333333333333";

describe("manual results request parser", () => {
  it("accepts exact hundredth scores and a reasoned complete pair", () => {
    expect(parseManualResultsRequest({
      season_id: seasonId,
      week: 3,
      reason: "ESPN did not publish this completed matchup.",
      matchups: [{
        home_season_team_id: homeId,
        away_season_team_id: awayId,
        home_score: 123.45,
        away_score: 101.2,
      }],
    })).toMatchObject({ seasonId, week: 3 });
  });

  it("rejects malformed, over-precise, and duplicate team evidence", () => {
    expect(parseManualResultsRequest({ season_id: "nope", week: 1 })).toBeNull();
    expect(parseManualResultsRequest({
      season_id: seasonId,
      week: 3,
      reason: "This reason is sufficiently long.",
      matchups: [{
        home_season_team_id: homeId,
        away_season_team_id: awayId,
        home_score: 123.456,
        away_score: 100,
      }],
    })).toBeNull();
    expect(parseManualResultsRequest({
      season_id: seasonId,
      week: 3,
      reason: "This reason is sufficiently long.",
      matchups: [
        { home_season_team_id: homeId, away_season_team_id: awayId, home_score: 1, away_score: 2 },
        { home_season_team_id: homeId, away_season_team_id: seasonId, home_score: 3, away_score: 4 },
      ],
    })).toBeNull();
  });
});
