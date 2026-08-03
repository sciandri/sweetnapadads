import {
  parseManualResultsRequest,
  REQUEST_KEY_PATTERN,
} from "@/lib/competition/manual-results";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

type ErrorCode =
  | "invalid_request"
  | "unauthorized"
  | "season_not_found"
  | "forbidden"
  | "correction_missing_source"
  | "correction_rejected"
  | "save_failed";

function errorResponse(status: number, code: ErrorCode) {
  return Response.json({ error: code }, { status });
}

async function handlePost(request: Request) {
  if (!request.headers.get("content-type")?.includes("application/json")) {
    return errorResponse(400, "invalid_request");
  }
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  const requestKey = request.headers.get("idempotency-key") ?? "";
  if (
    (Number.isFinite(contentLength) && contentLength > 32_768)
    || !REQUEST_KEY_PATTERN.test(requestKey)
  ) return errorResponse(400, "invalid_request");

  let body: unknown;
  try {
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).byteLength > 32_768) {
      return errorResponse(400, "invalid_request");
    }
    body = JSON.parse(rawBody);
  } catch {
    return errorResponse(400, "invalid_request");
  }
  const parsed = parseManualResultsRequest(body);
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

  const { data, error } = await supabase.rpc("record_week_result_correction", {
    target_season_id: parsed.seasonId,
    target_week: parsed.week,
    target_reason: parsed.reason,
    target_request_key: requestKey,
    target_matchups: parsed.matchups,
  });
  if (error) {
    const databaseError = error as { code?: unknown; message?: unknown };
    if (
      databaseError.code === "22023"
      && databaseError.message === "result correction requires one complete accepted week"
    ) return errorResponse(409, "correction_missing_source");
    return errorResponse(409, "correction_rejected");
  }

  const result = data as Record<string, unknown> | null;
  return Response.json({
    status: result?.status === "already_recorded" ? "already_recorded" : "recorded",
    season_id: parsed.seasonId,
    week: parsed.week,
    matchup_count: typeof result?.matchup_count === "number" ? result.matchup_count : parsed.matchups.length,
    result_count: typeof result?.result_count === "number" ? result.result_count : parsed.matchups.length * 2,
    pending_tie: result?.pending_tie === true,
  });
}

export async function POST(request: Request) {
  try {
    return await handlePost(request);
  } catch {
    return errorResponse(500, "save_failed");
  }
}
