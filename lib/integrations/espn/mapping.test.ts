import { describe, expect, it } from "vitest";

import { parseEspnMappingUpdate } from "@/lib/integrations/espn/mapping";

const seasonId = "11111111-1111-4111-8111-111111111111";
const teamOne = "22222222-2222-4222-8222-222222222222";
const teamTwo = "33333333-3333-4333-8333-333333333333";

describe("ESPN mapping update validation", () => {
  it("accepts an exact dynamic mapping list", () => {
    expect(
      parseEspnMappingUpdate({
        season_id: seasonId,
        mappings: [
          { season_team_id: teamOne, espn_team_id: 1 },
          { season_team_id: teamTwo, espn_team_id: 12 },
        ],
      }),
    ).toEqual({
      seasonId,
      mappings: [
        { season_team_id: teamOne, espn_team_id: 1 },
        { season_team_id: teamTwo, espn_team_id: 12 },
      ],
    });
  });

  it("rejects malformed or empty input", () => {
    expect(parseEspnMappingUpdate(null)).toBeNull();
    expect(parseEspnMappingUpdate({ season_id: seasonId, mappings: [] })).toBeNull();
    expect(parseEspnMappingUpdate({ season_id: "2026", mappings: [] })).toBeNull();
  });

  it("rejects invalid team IDs and nonpositive ESPN IDs", () => {
    expect(
      parseEspnMappingUpdate({
        season_id: seasonId,
        mappings: [{ season_team_id: "team", espn_team_id: 1 }],
      }),
    ).toBeNull();
    expect(
      parseEspnMappingUpdate({
        season_id: seasonId,
        mappings: [{ season_team_id: teamOne, espn_team_id: 0 }],
      }),
    ).toBeNull();
  });

  it("rejects duplicate season-team or ESPN identifiers", () => {
    expect(
      parseEspnMappingUpdate({
        season_id: seasonId,
        mappings: [
          { season_team_id: teamOne, espn_team_id: 1 },
          { season_team_id: teamOne, espn_team_id: 2 },
        ],
      }),
    ).toBeNull();
    expect(
      parseEspnMappingUpdate({
        season_id: seasonId,
        mappings: [
          { season_team_id: teamOne, espn_team_id: 1 },
          { season_team_id: teamTwo, espn_team_id: 1 },
        ],
      }),
    ).toBeNull();
  });
});
