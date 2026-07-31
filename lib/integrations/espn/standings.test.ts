import { readFile } from "node:fs/promises";
import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  buildEspnStandingsIngestion,
  normalizeEspnStandings,
  sha256,
} from "@/lib/integrations/espn/standings";
import type { EspnLeaguePayload } from "@/lib/integrations/espn/types";

const fixturePath = path.join(
  process.cwd(),
  "lib/integrations/espn/fixtures/standings-complete.json",
);

const mappings = [
  { espnTeamId: 21, seasonTeamId: "season-team-a" },
  { espnTeamId: 22, seasonTeamId: "season-team-b" },
  { espnTeamId: 23, seasonTeamId: "season-team-c" },
];

async function fixture() {
  return JSON.parse(await readFile(fixturePath, "utf8")) as EspnLeaguePayload;
}

describe("ESPN standings normalization", () => {
  it("preserves ESPN final rank instead of recalculating from wins or seeds", async () => {
    const standings = normalizeEspnStandings({
      payload: await fixture(),
      expectedLeagueId: 999,
      expectedSeason: 2025,
      mappings,
    });

    expect(standings.map(({ espn_team_id }) => espn_team_id)).toEqual([
      21, 22, 23,
    ]);
    expect(standings.map(({ official_rank }) => official_rank)).toEqual([
      1, 2, 3,
    ]);
    expect(standings[0]).toEqual(
      expect.objectContaining({
        playoff_seed: 3,
        points_for: 1400.12,
        points_against: 1300.56,
        record_summary: "8-6",
        streak: "W2",
      }),
    );
  });

  it("uses ESPN playoff seed as official order during an active season", async () => {
    const payload = await fixture();
    payload.status = {
      ...payload.status,
      latestScoringPeriod: 14,
      finalScoringPeriod: 17,
    };

    const standings = normalizeEspnStandings({
      payload,
      expectedLeagueId: 999,
      expectedSeason: 2025,
      mappings,
    });

    expect(standings.map(({ espn_team_id }) => espn_team_id)).toEqual([
      22, 23, 21,
    ]);
  });

  it("refuses preseason zeros rather than inventing standings order", async () => {
    const payload = await fixture();
    payload.status = { finalScoringPeriod: 17, latestScoringPeriod: 0 };
    payload.teams = (payload.teams as Array<Record<string, unknown>>).map(
      (team) => ({ ...team, playoffSeed: 0, rankCalculatedFinal: 0 }),
    );

    expect(() =>
      normalizeEspnStandings({
        payload,
        expectedLeagueId: 999,
        expectedSeason: 2025,
        mappings,
      }),
    ).toThrowError(
      expect.objectContaining({
        code: "standings_unavailable",
      }),
    );
  });

  it("requires an exact mapping for every ESPN team", async () => {
    const payload = await fixture();

    expect(() =>
      normalizeEspnStandings({
        payload,
        expectedLeagueId: 999,
        expectedSeason: 2025,
        mappings: mappings.slice(0, 2),
      }),
    ).toThrowError(
      expect.objectContaining({
        code: "team_mapping_incomplete",
      }),
    );
  });

  it("supports a twelve-team season without changing application constants", () => {
    const twelveTeams = Array.from({ length: 12 }, (_, index) => ({
      id: index + 1,
      playoffSeed: index + 1,
      rankCalculatedFinal: index + 1,
      points: 1000 + index,
      record: {
        overall: {
          wins: 12 - index,
          losses: index,
          ties: 0,
          pointsFor: 1000 + index,
          pointsAgainst: 900 + index,
          streakLength: 0,
          streakType: "NONE",
        },
      },
    }));

    const standings = normalizeEspnStandings({
      payload: {
        id: 999,
        seasonId: 2026,
        teams: twelveTeams,
        status: { finalScoringPeriod: 17, latestScoringPeriod: 14 },
      },
      expectedLeagueId: 999,
      expectedSeason: 2026,
      mappings: twelveTeams.map((team) => ({
        espnTeamId: team.id,
        seasonTeamId: `season-team-${team.id}`,
      })),
    });

    expect(standings).toHaveLength(12);
    expect(standings.at(-1)?.official_rank).toBe(12);
  });

  it("keeps normalized source evidence free of team names and owner IDs", async () => {
    const [standing] = normalizeEspnStandings({
      payload: await fixture(),
      expectedLeagueId: 999,
      expectedSeason: 2025,
      mappings,
    });
    const evidence = JSON.stringify(standing.source_record);

    expect(evidence).not.toContain("Redacted Team");
    expect(evidence).not.toContain("redacted-owner");
    expect(standing.record_summary).toBe("8-6");
  });

  it("produces deterministic lowercase SHA-256 evidence hashes", () => {
    expect(sha256("official ESPN payload")).toMatch(/^[0-9a-f]{64}$/);
    expect(sha256("official ESPN payload")).toBe(
      sha256("official ESPN payload"),
    );
  });

  it("builds the exact atomic ingestion boundary without private team fields", async () => {
    const payload = await fixture();
    const rawText = JSON.stringify(payload);
    const ingestion = buildEspnStandingsIngestion({
      leagueId: "league-uuid",
      seasonId: "season-uuid",
      seasonYear: 2025,
      espnLeagueId: 999,
      response: {
        endpointPath: "/apis/v3/games/ffl/seasons/2025/segments/0/leagues/999",
        fetchedAt: "2025-12-29T00:00:05.000Z",
        httpStatus: 200,
        payload,
        rawText,
      },
      mappings,
    });

    expect(ingestion.target_entries).toHaveLength(3);
    expect(ingestion.target_payload_sha256).toBe(sha256(rawText));
    expect(ingestion.target_idempotency_key).toContain(
      ingestion.target_payload_sha256,
    );
    expect(ingestion.target_captured_at).toBe("2025-12-28T08:00:00.000Z");
    expect(JSON.stringify(ingestion.target_entries)).not.toContain(
      "redacted-owner",
    );
  });
});
