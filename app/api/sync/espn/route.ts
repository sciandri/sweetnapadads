import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";
import {
  fetchEspnStandings,
  readEspnConfig,
} from "@/lib/integrations/espn/client";
import { ingestEspnStandings } from "@/lib/integrations/espn/ingest";
import {
  bearerToken,
  parseEspnSyncRequest,
  secretsMatch,
} from "@/lib/integrations/espn/security";
import { EspnStandingsError } from "@/lib/integrations/espn/standings";
import type { EspnTeamMapping } from "@/lib/integrations/espn/types";
import { operationalEvent } from "@/lib/operations/telemetry";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

type ErrorCode =
  | "invalid_request"
  | "unauthorized"
  | "forbidden"
  | "season_not_found"
  | "team_mapping_incomplete"
  | "integration_not_configured"
  | "standings_unavailable"
  | "upstream_failed"
  | "ingestion_failed";

function errorResponse(status: number, code: ErrorCode) {
  return Response.json({ error: code }, { status });
}

async function requestBody(request: Request) {
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (Number.isFinite(contentLength) && contentLength > 4_096) return null;
  try {
    return (await request.json()) as unknown;
  } catch {
    return null;
  }
}

async function handlePost(request: Request) {
  if (!request.headers.get("content-type")?.includes("application/json")) {
    return errorResponse(400, "invalid_request");
  }
  const parsed = parseEspnSyncRequest(
    await requestBody(request),
    request.headers.get("idempotency-key"),
  );
  if (!parsed) return errorResponse(400, "invalid_request");

  const automationAuthorized = secretsMatch(
    bearerToken(request.headers.get("authorization")),
    process.env.SYNC_SECRET,
  );
  let callerClient: Awaited<ReturnType<typeof createClient>> | null = null;
  let userId: string | null = null;

  if (!automationAuthorized) {
    callerClient = await createClient();
    const { data } = await callerClient.auth.getClaims();
    userId = typeof data?.claims?.sub === "string" ? data.claims.sub : null;
    if (!userId) return errorResponse(401, "unauthorized");
  }

  let admin;
  try {
    admin = createAdminClient();
  } catch {
    return errorResponse(503, "integration_not_configured");
  }
  const { data: season, error: seasonError } = await admin
    .from("seasons")
    .select("id, league_id, year")
    .eq("id", parsed.seasonId)
    .maybeSingle();
  if (seasonError) return errorResponse(500, "ingestion_failed");
  if (!season) return errorResponse(404, "season_not_found");

  if (!automationAuthorized && callerClient && userId) {
    const { data: membership, error: membershipError } = await callerClient
      .from("league_memberships")
      .select("role")
      .eq("league_id", season.league_id)
      .eq("user_id", userId)
      .eq("status", "active")
      .eq("role", "commissioner")
      .maybeSingle();
    if (membershipError || membership?.role !== "commissioner") {
      return errorResponse(403, "forbidden");
    }
  }

  const { data: seasonTeams, error: mappingsError } = await admin
    .from("season_teams")
    .select("id, espn_team_id")
    .eq("season_id", season.id)
    .eq("status", "active")
    .order("id");
  if (mappingsError) return errorResponse(500, "ingestion_failed");
  if (
    !seasonTeams?.length ||
    seasonTeams.some(
      (team) =>
        !Number.isInteger(team.espn_team_id) || Number(team.espn_team_id) <= 0,
    )
  ) {
    return errorResponse(409, "team_mapping_incomplete");
  }

  const mappings: EspnTeamMapping[] = seasonTeams.map((team) => ({
    espnTeamId: Number(team.espn_team_id),
    seasonTeamId: team.id,
  }));

  let config;
  try {
    config = readEspnConfig();
  } catch {
    return errorResponse(503, "integration_not_configured");
  }

  let response;
  try {
    response = await fetchEspnStandings(season.year, config);
  } catch {
    return errorResponse(502, "upstream_failed");
  }

  try {
    const result = await ingestEspnStandings({
      supabase: admin,
      leagueId: season.league_id,
      seasonId: season.id,
      seasonYear: season.year,
      espnLeagueId: config.leagueId,
      response,
      mappings,
      idempotencyKey: parsed.idempotencyKey,
    });

    const responseBody = {
      status: result?.status ?? "recorded",
      season_id: season.id,
      team_count: mappings.length,
      matchup_count:
        typeof result?.matchup_count === "number" ? result.matchup_count : 0,
      award_week_count:
        typeof result?.award_week_count === "number"
          ? result.award_week_count
          : 0,
      pending_tie_weeks: Array.isArray(result?.pending_tie_weeks)
        ? result.pending_tie_weeks.filter(
            (week: unknown) => Number.isInteger(week) && Number(week) > 0,
          )
        : [],
    };
    operationalEvent("espn_sync_completed", {
      season_id: season.id,
      team_count: responseBody.team_count,
      matchup_count: responseBody.matchup_count,
      award_week_count: responseBody.award_week_count,
      pending_tie_count: responseBody.pending_tie_weeks.length,
    });
    return Response.json(responseBody);
  } catch (error) {
    if (
      error instanceof EspnStandingsError &&
      error.code === "standings_unavailable"
    ) {
      return errorResponse(409, "standings_unavailable");
    }
    if (
      error instanceof EspnStandingsError &&
      error.code === "team_mapping_incomplete"
    ) {
      return errorResponse(409, "team_mapping_incomplete");
    }
    if (error instanceof EspnStandingsError) {
      return errorResponse(502, "upstream_failed");
    }
    return errorResponse(500, "ingestion_failed");
  }
}

export async function POST(request: Request) {
  try {
    return await handlePost(request);
  } catch {
    operationalEvent("espn_sync_unexpected_failure", {
      route: "/api/sync/espn",
      status: 500,
    });
    return errorResponse(500, "ingestion_failed");
  }
}
