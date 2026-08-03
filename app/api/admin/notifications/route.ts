import {
  NOTIFICATION_KEY_PATTERN,
  parseNotificationRequest,
} from "@/lib/notifications/input";
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
    const key = request.headers.get("idempotency-key") ?? "";
    const rawBody = await request.text();
    if (!NOTIFICATION_KEY_PATTERN.test(key) || new TextEncoder().encode(rawBody).byteLength > 8_192) {
      return errorResponse(400, "invalid_request");
    }
    let body: unknown;
    try {
      body = JSON.parse(rawBody);
    } catch {
      return errorResponse(400, "invalid_request");
    }
    const parsed = parseNotificationRequest(body);
    if (!parsed) return errorResponse(400, "invalid_request");

    const supabase = await createClient();
    const { data: claimsData } = await supabase.auth.getClaims();
    const userId = claimsData?.claims?.sub;
    if (typeof userId !== "string") return errorResponse(401, "unauthorized");

    const { data: membership, error: membershipError } = await supabase
      .from("league_memberships")
      .select("role")
      .eq("league_id", parsed.leagueId)
      .eq("user_id", userId)
      .eq("status", "active")
      .eq("role", "commissioner")
      .maybeSingle();
    if (membershipError || membership?.role !== "commissioner") {
      return errorResponse(403, "forbidden");
    }

    const { data, error } = await supabase.rpc("publish_league_notification", {
      target_league_id: parsed.leagueId,
      target_season_id: parsed.seasonId,
      target_kind: parsed.kind,
      target_audience: parsed.audience,
      target_title: parsed.title,
      target_body: parsed.body,
      target_source_key: key,
    });
    if (error) return errorResponse(409, "publish_rejected");
    const result = data as Record<string, unknown> | null;
    return Response.json({
      status: result?.status === "already_published" ? "already_published" : "published",
      notification_id: typeof result?.notification_id === "string" ? result.notification_id : null,
      in_app_delivery_count: typeof result?.in_app_delivery_count === "number" ? result.in_app_delivery_count : 0,
    });
  } catch {
    return errorResponse(500, "save_failed");
  }
}
