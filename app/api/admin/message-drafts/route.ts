import type { CommissionerMessageContext } from "@/lib/messages/context";
import {
  generateMessageDrafts,
  MessageGenerationError,
} from "@/lib/messages/generator";
import { parseMessageDraftRequest } from "@/lib/messages/input";
import { operationalEvent } from "@/lib/operations/telemetry";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

function errorResponse(status: number, error: string) {
  return Response.json({ error }, { status });
}

export async function POST(request: Request) {
  try {
    if (!request.headers.get("content-type")?.includes("application/json")) {
      return errorResponse(400, "invalid_request");
    }
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).byteLength > 8_192) {
      return errorResponse(400, "invalid_request");
    }
    let body: unknown;
    try {
      body = JSON.parse(rawBody);
    } catch {
      return errorResponse(400, "invalid_request");
    }
    const parsed = parseMessageDraftRequest(body);
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
    if (seasonError || !season) return errorResponse(404, "season_not_found");

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

    const apiKey = process.env.OPENAI_API_KEY?.trim();
    if (!apiKey) return errorResponse(503, "generation_not_configured");

    const { data: contextData, error: contextError } = await supabase.rpc(
      "get_commissioner_message_context",
      { target_season_id: parsed.seasonId, target_week: parsed.week },
    );
    if (contextError || !contextData) {
      return errorResponse(409, "context_unavailable");
    }

    const drafts = await generateMessageDrafts({
      apiKey,
      context: contextData as CommissionerMessageContext,
      request: parsed,
    });
    operationalEvent("message_drafts_generated", {
      season_id: parsed.seasonId,
      week: parsed.week,
      draft_count: drafts.length,
    });
    return Response.json({ drafts });
  } catch (error) {
    if (error instanceof MessageGenerationError) {
      return errorResponse(error.code === "generation_refused" ? 422 : 502, error.code);
    }
    return errorResponse(500, "generation_failed");
  }
}
