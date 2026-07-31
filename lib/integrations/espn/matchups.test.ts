import { readFile } from "node:fs/promises";
import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  EspnMatchupsError,
  normalizeEspnMatchups,
} from "@/lib/integrations/espn/matchups";
import type { EspnLeaguePayload } from "@/lib/integrations/espn/types";

const fixturePath = path.join(
  process.cwd(),
  "lib/integrations/espn/fixtures/matchups-complete.json",
);
const mappings = [21, 22, 23, 24].map((espnTeamId) => ({
  espnTeamId,
  seasonTeamId: `season-team-${espnTeamId}`,
}));

async function fixture() {
  return JSON.parse(await readFile(fixturePath, "utf8")) as EspnLeaguePayload;
}

describe("ESPN matchup normalization", () => {
  it("preserves ESPN scores, winners, and reciprocal opponents", async () => {
    const matchups = normalizeEspnMatchups({
      payload: await fixture(),
      expectedLeagueId: 999,
      expectedSeason: 2025,
      mappings,
    });

    expect(matchups).toHaveLength(3);
    expect(matchups[0]).toMatchObject({
      espn_matchup_id: 1,
      week: 1,
      phase: "regular_season",
      results: [
        { score: 103.41, result: "win", opponent_season_team_id: "season-team-22" },
        { score: 80.44, result: "loss", opponent_season_team_id: "season-team-21" },
      ],
    });
    expect(matchups[1].results.map((result) => result.result)).toEqual([
      "tie",
      "tie",
    ]);
  });

  it("derives postseason from ESPN season settings, not a hardcoded week", async () => {
    const matchups = normalizeEspnMatchups({
      payload: await fixture(),
      expectedLeagueId: 999,
      expectedSeason: 2025,
      mappings,
    });

    expect(matchups.at(-1)).toMatchObject({ week: 15, phase: "postseason" });
  });

  it("excludes future and undecided matchups", async () => {
    const payload = await fixture();
    payload.status = { ...payload.status, latestScoringPeriod: 1 };

    const matchups = normalizeEspnMatchups({
      payload,
      expectedLeagueId: 999,
      expectedSeason: 2025,
      mappings,
    });

    expect(matchups.map((matchup) => matchup.espn_matchup_id)).toEqual([1, 2]);
  });

  it("requires a mapping for every team in a completed matchup", async () => {
    const payload = await fixture();

    expect(() =>
      normalizeEspnMatchups({
        payload,
        expectedLeagueId: 999,
        expectedSeason: 2025,
        mappings: mappings.slice(0, 3),
      }),
    ).toThrowError(expect.objectContaining({ code: "team_mapping_incomplete" }));
  });

  it("rejects duplicate matchup IDs and invalid completed winners", async () => {
    const duplicate = await fixture();
    const schedule = duplicate.schedule as Array<Record<string, unknown>>;
    schedule[1] = { ...schedule[1], id: schedule[0].id };

    expect(() =>
      normalizeEspnMatchups({
        payload: duplicate,
        expectedLeagueId: 999,
        expectedSeason: 2025,
        mappings,
      }),
    ).toThrow(EspnMatchupsError);

    const invalid = await fixture();
    (invalid.schedule as Array<Record<string, unknown>>)[0].winner = "PENDING";
    expect(() =>
      normalizeEspnMatchups({
        payload: invalid,
        expectedLeagueId: 999,
        expectedSeason: 2025,
        mappings,
      }),
    ).toThrowError(expect.objectContaining({ code: "invalid_payload" }));
  });
});
