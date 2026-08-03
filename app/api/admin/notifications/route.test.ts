import { beforeEach, describe, expect, it, vi } from "vitest";

import { createClient } from "@/lib/supabase/server";

import { POST } from "./route";

vi.mock("@/lib/supabase/server", () => ({ createClient: vi.fn() }));

const leagueId = "11111111-1111-4111-8111-111111111111";
const seasonId = "22222222-2222-4222-8222-222222222222";

function client({ authenticated = true, commissioner = true, rpcError = null }: {
  authenticated?: boolean;
  commissioner?: boolean;
  rpcError?: { message: string } | null;
} = {}) {
  const query = { select: vi.fn(), eq: vi.fn(), maybeSingle: vi.fn() };
  query.select.mockReturnValue(query);
  query.eq.mockReturnValue(query);
  query.maybeSingle.mockResolvedValue({ data: commissioner ? { role: "commissioner" } : null, error: null });
  return {
    auth: { getClaims: vi.fn().mockResolvedValue({ data: authenticated ? { claims: { sub: "user-1" } } : { claims: null } }) },
    from: vi.fn(() => query),
    rpc: vi.fn().mockResolvedValue({ data: rpcError ? null : { status: "published", notification_id: "notice-1", in_app_delivery_count: 12 }, error: rpcError }),
  };
}

const body = {
  league_id: leagueId,
  season_id: seasonId,
  kind: "reminder",
  audience: "all_members",
  title: "Draft reminder",
  body: "Bring your dues to the draft.",
};

function request(value: unknown, key = "notification:test:draft") {
  return new Request("https://sweetnapadads.test/api/admin/notifications", {
    method: "POST",
    headers: { "content-type": "application/json", "idempotency-key": key },
    body: JSON.stringify(value),
  });
}

describe("POST /api/admin/notifications", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(createClient).mockResolvedValue(client() as never);
  });

  it("rejects invalid evidence before authentication", async () => {
    expect((await POST(request(body, ""))).status).toBe(400);
    expect((await POST(request({ ...body, audience: "public" }))).status).toBe(400);
    expect(createClient).not.toHaveBeenCalled();
  });

  it("requires an active commissioner", async () => {
    vi.mocked(createClient).mockResolvedValue(client({ authenticated: false }) as never);
    expect((await POST(request(body))).status).toBe(401);
    vi.mocked(createClient).mockResolvedValue(client({ commissioner: false }) as never);
    expect((await POST(request(body))).status).toBe(403);
  });

  it("publishes through the atomic RPC and returns bounded evidence", async () => {
    const supabase = client();
    vi.mocked(createClient).mockResolvedValue(supabase as never);
    const response = await POST(request(body));
    expect(await response.json()).toEqual({ status: "published", notification_id: "notice-1", in_app_delivery_count: 12 });
    expect(supabase.rpc).toHaveBeenCalledWith("publish_league_notification", expect.objectContaining({
      target_league_id: leagueId,
      target_source_key: "notification:test:draft",
    }));
  });

  it("redacts database and unexpected failures", async () => {
    vi.mocked(createClient).mockResolvedValue(client({ rpcError: { message: "private" } }) as never);
    expect(await (await POST(request(body))).json()).toEqual({ error: "publish_rejected" });
    vi.mocked(createClient).mockRejectedValue(new Error("private"));
    expect(await (await POST(request(body))).json()).toEqual({ error: "save_failed" });
  });
});
