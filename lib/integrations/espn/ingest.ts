import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { buildEspnStandingsIngestion } from "@/lib/integrations/espn/standings";
import type {
  EspnLeaguePayload,
  EspnTeamMapping,
} from "@/lib/integrations/espn/types";

export async function ingestEspnStandings({
  supabase,
  leagueId,
  seasonId,
  seasonYear,
  espnLeagueId,
  response,
  mappings,
}: {
  supabase: SupabaseClient;
  leagueId: string;
  seasonId: string;
  seasonYear: number;
  espnLeagueId: number;
  response: {
    endpointPath: string;
    fetchedAt: string;
    httpStatus: number;
    payload: EspnLeaguePayload;
    rawText: string;
  };
  mappings: EspnTeamMapping[];
}) {
  const ingestion = buildEspnStandingsIngestion({
    leagueId,
    seasonId,
    seasonYear,
    espnLeagueId,
    response,
    mappings,
  });
  const { data, error } = await supabase.rpc(
    "record_espn_standings_snapshot",
    ingestion,
  );

  if (error) throw new Error(`ESPN standings ingestion failed: ${error.message}`);
  return data;
}
