import "server-only";

import type { EspnLeaguePayload } from "@/lib/integrations/espn/types";

export type EspnConfig = {
  leagueId: number;
  s2: string;
  swid: string;
};

export function readEspnConfig(environment: NodeJS.ProcessEnv = process.env) {
  const leagueId = environment.ESPN_LEAGUE_ID;
  const s2 = environment.ESPN_S2;
  const swid = environment.ESPN_SWID;

  if (!leagueId || !/^\d+$/.test(leagueId) || !s2 || !swid) {
    throw new Error("ESPN integration is not configured");
  }

  return { leagueId: Number(leagueId), s2, swid } satisfies EspnConfig;
}

export async function fetchEspnStandings(
  season: number,
  config: EspnConfig,
  fetchImplementation: typeof fetch = fetch,
) {
  if (!Number.isInteger(season) || season < 2000 || season > 2100) {
    throw new Error("ESPN season must be between 2000 and 2100");
  }
  const endpointPath =
    `/apis/v3/games/ffl/seasons/${season}/segments/0/leagues/` +
    `${config.leagueId}`;
  const query =
    "view=mSettings&view=mTeam&view=mStandings&view=mMatchup&" +
    "view=mMatchupScore&view=mScoreboard";
  const fetchedAt = new Date().toISOString();
  const response = await fetchImplementation(
    `https://lm-api-reads.fantasy.espn.com${endpointPath}?${query}`,
    {
      headers: {
        Accept: "application/json",
        Cookie: `espn_s2=${config.s2}; SWID=${config.swid}`,
        "User-Agent": "sweetnapadads/1.0",
      },
      signal: AbortSignal.timeout(15_000),
    },
  );
  const rawText = await response.text();

  if (!response.ok) {
    throw new Error(`ESPN standings request failed with HTTP ${response.status}`);
  }

  let payload: EspnLeaguePayload;
  try {
    payload = JSON.parse(rawText) as EspnLeaguePayload;
  } catch {
    throw new Error("ESPN standings response was not valid JSON");
  }

  return {
    endpointPath,
    fetchedAt,
    httpStatus: response.status,
    payload,
    rawText,
  };
}
