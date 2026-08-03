import { beforeEach, describe, expect, it, vi } from "vitest";

import { createClient } from "@/lib/supabase/server";

import { POST } from "./route";

vi.mock("@/lib/supabase/server", () => ({ createClient: vi.fn() }));

const seasonId = "11111111-1111-4111-8111-111111111111";
const leagueId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const matchups = [{
  home_season_team_id: "44444444-4444-4444-8444-444444444444",
  away_season_team_id: "55555555-5555-4555-8555-555555555555",
  home_score: 120.5,
  away_score: 110.25,
}];

function queryBuilder(data: unknown, error: unknown = null) {
  const builder = { select: vi.fn(), eq: vi.fn(), maybeSingle: vi.fn() };
  builder.select.mockReturnValue(builder);
  builder.eq.mockReturnValue(builder);
  builder.maybeSingle.mockResolvedValue({ data, error });
  return builder;
}

function client({
  authenticated = true,
  commissioner = true,
  seasonExists = true,
  rpcError = null,
}: {
  authenticated?: boolean;
  commissioner?: boolean;
  seasonExists?: boolean;
  rpcError?: { code?: string } | null;
} = {}) {
  const seasonQuery = queryBuilder(seasonExists ? { league_id: leagueId } : null);
  const membershipQuery = queryBuilder(commissioner ? { role: "commissioner" } : null);
  return {
    auth: { getClaims: vi.fn().mockResolvedValue({ data: authenticated ? { claims: { sub: userId } } : { claims: null } }) },
    from: vi.fn((table: string) => table === "seasons" ? seasonQuery : membershipQuery),
    rpc: vi.fn().mockResolvedValue({
      data: rpcError ? null : { status: "recorded", matchup_count: 1, result_count: 2, pending_tie: false },
      error: rpcError,
    }),
  };
}

function request(body: unknown, key = "manual:test:week-3", contentType = "application/json") {
  return new Request("https://sweetnapadads.test/api/admin/results", {
    method: "POST",
    headers: { "content-type": contentType, "idempotency-key": key },
    body: JSON.stringify(body),
  });
}

const body = {
  season_id: seasonId,
  week: 3,
  reason: "ESPN did not publish the final week results.",
  matchups,
};

describe("POST /api/admin/results", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(createClient).mockResolvedValue(client() as never);
  });

  it("rejects malformed bodies and missing idempotency evidence", async () => {
    expect((await POST(request(body, "", "application/json"))).status).toBe(400);
    expect((await POST(request({ ...body, matchups: [] }))).status).toBe(400);
    expect((await POST(request({ ...body, ignored: "x".repeat(33_000) }))).status).toBe(400);
    expect(createClient).not.toHaveBeenCalled();
  });

  it("requires an active commissioner", async () => {
    vi.mocked(createClient).mockResolvedValue(client({ authenticated: false }) as never);
    expect((await POST(request(body))).status).toBe(401);
    vi.mocked(createClient).mockResolvedValue(client({ commissioner: false }) as never);
    expect((await POST(request(body))).status).toBe(403);
  });

  it("passes validated evidence to the atomic RPC", async () => {
    const supabase = client();
    vi.mocked(createClient).mockResolvedValue(supabase as never);
    const response = await POST(request(body));
    expect(await response.json()).toMatchObject({ status: "recorded", week: 3, matchup_count: 1, result_count: 2 });
    expect(supabase.rpc).toHaveBeenCalledWith("record_manual_week_results", {
      target_season_id: seasonId,
      target_week: 3,
      target_reason: body.reason,
      target_request_key: "manual:test:week-3",
      target_matchups: matchups,
    });
  });

  it("returns stable conflict and redacted failure codes", async () => {
    vi.mocked(createClient).mockResolvedValue(client({ rpcError: { code: "23505" } }) as never);
    expect(await (await POST(request(body))).json()).toEqual({ error: "results_already_exist" });
    vi.mocked(createClient).mockRejectedValue(new Error("private detail"));
    expect(await (await POST(request(body))).json()).toEqual({ error: "save_failed" });
  });
});
