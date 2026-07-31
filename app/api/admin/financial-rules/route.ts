import { parseFinancialRuleUpdate } from "@/lib/finance/rules";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

type ErrorCode =
  | "invalid_request"
  | "unauthorized"
  | "season_not_found"
  | "forbidden"
  | "rules_rejected"
  | "save_failed";

function errorResponse(status: number, code: ErrorCode) {
  return Response.json({ error: code }, { status });
}

async function handlePatch(request: Request) {
  if (!request.headers.get("content-type")?.includes("application/json")) {
    return errorResponse(400, "invalid_request");
  }
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (Number.isFinite(contentLength) && contentLength > 32_768) {
    return errorResponse(400, "invalid_request");
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return errorResponse(400, "invalid_request");
  }
  const parsed = parseFinancialRuleUpdate(body);
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

  const { data, error } = await supabase.rpc("set_season_financial_rules", {
    target_season_id: parsed.seasonId,
    target_rules: parsed.rules,
  });
  if (error) return errorResponse(409, "rules_rejected");

  const result = data as { rule_count?: unknown } | null;
  return Response.json({
    status: "saved",
    season_id: parsed.seasonId,
    rule_count:
      typeof result?.rule_count === "number"
        ? result.rule_count
        : parsed.rules.length,
  });
}

export async function PATCH(request: Request) {
  try {
    return await handlePatch(request);
  } catch {
    return errorResponse(500, "save_failed");
  }
}
