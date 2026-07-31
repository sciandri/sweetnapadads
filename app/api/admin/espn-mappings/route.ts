import { parseEspnMappingUpdate } from "@/lib/integrations/espn/mapping";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

type ErrorCode =
  | "invalid_request"
  | "unauthorized"
  | "season_not_found"
  | "forbidden"
  | "mapping_rejected"
  | "save_failed";

function errorResponse(status: number, code: ErrorCode) {
  return Response.json({ error: code }, { status });
}

async function handlePatch(request: Request) {
  if (!request.headers.get("content-type")?.includes("application/json")) {
    return errorResponse(400, "invalid_request");
  }
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (Number.isFinite(contentLength) && contentLength > 16_384) {
    return errorResponse(400, "invalid_request");
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return errorResponse(400, "invalid_request");
  }
  const parsed = parseEspnMappingUpdate(body);
  if (!parsed) return errorResponse(400, "invalid_request");

  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (typeof userId !== "string") return errorResponse(401, "unauthorized");

  const { data: season, error: seasonError } = await supabase
    .from("seasons")
    .select("league_id")
    .eq("id", parsed.seasonId)
    .maybeSingle();
  if (seasonError) return errorResponse(500, "save_failed");
  if (!season) return errorResponse(404, "season_not_found");

  const { data: membership, error: membershipError } = await supabase
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

  const { data, error } = await supabase.rpc(
    "set_espn_season_team_mappings",
    {
      target_season_id: parsed.seasonId,
      target_mappings: parsed.mappings,
    },
  );
  if (error) return errorResponse(409, "mapping_rejected");

  const result = data as { mapped_count?: unknown; status?: unknown } | null;
  return Response.json({
    status: "saved",
    season_id: parsed.seasonId,
    mapped_count:
      typeof result?.mapped_count === "number"
        ? result.mapped_count
        : parsed.mappings.length,
  });
}

export async function PATCH(request: Request) {
  try {
    return await handlePatch(request);
  } catch {
    return errorResponse(500, "save_failed");
  }
}
