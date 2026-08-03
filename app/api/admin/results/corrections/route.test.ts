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
  rpcError = null,
}: {
  authenticated?: boolean;
  commissioner?: boolean;
  rpcError?: { code?: string; message?: string } | null;
} = {}) {
  const seasonQuery = queryBuilder({ league_id: leagueId });
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

const body = {
  season_id: seasonId,
  week: 3,
  reason: "The accepted scores were transposed in the source.",
  matchups,
};

function request(value: unknown, key = "correction:test:week-3") {
  return new Request("https://sweetnapadads.test/api/admin/results/corrections", {
    method: "POST",
    headers: { "content-type": "application/json", "idempotency-key": key },
    body: JSON.stringify(value),
  });
}

describe("POST /api/admin/results/corrections", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(createClient).mockResolvedValue(client() as never);
  });

  it("rejects invalid and oversized evidence before authentication", async () => {
    expect((await POST(request(body, ""))).status).toBe(400);
    expect((await POST(request({ ...body, ignored: "x".repeat(33_000) }))).status).toBe(400);
    expect(createClient).not.toHaveBeenCalled();
  });

  it("requires an active commissioner", async () => {
    vi.mocked(createClient).mockResolvedValue(client({ authenticated: false }) as never);
    expect((await POST(request(body))).status).toBe(401);
    vi.mocked(createClient).mockResolvedValue(client({ commissioner: false }) as never);
    expect((await POST(request(body))).status).toBe(403);
  });

  it("passes validated evidence to the correction RPC", async () => {
    const supabase = client();
    vi.mocked(createClient).mockResolvedValue(supabase as never);
    expect((await POST(request(body))).status).toBe(200);
    expect(supabase.rpc).toHaveBeenCalledWith("record_week_result_correction", {
      target_season_id: seasonId,
      target_week: 3,
      target_reason: body.reason,
      target_request_key: "correction:test:week-3",
      target_matchups: matchups,
    });
  });

  it("returns stable missing-source and redacted failure codes", async () => {
    vi.mocked(createClient).mockResolvedValue(client({ rpcError: { code: "22023", message: "result correction requires one complete accepted week" } }) as never);
    expect(await (await POST(request(body))).json()).toEqual({ error: "correction_missing_source" });
    vi.mocked(createClient).mockRejectedValue(new Error("private detail"));
    expect(await (await POST(request(body))).json()).toEqual({ error: "save_failed" });
  });
});
