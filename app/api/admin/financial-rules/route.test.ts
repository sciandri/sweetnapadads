import { beforeEach, describe, expect, it, vi } from "vitest";

import { createClient } from "@/lib/supabase/server";

import { PATCH } from "./route";

vi.mock("@/lib/supabase/server", () => ({ createClient: vi.fn() }));

const seasonId = "11111111-1111-4111-8111-111111111111";
const leagueId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const rules = [
  {
    rule_key: "weekly_high_score",
    rule_kind: "weekly_high_score",
    label: "Weekly high score",
    direction: "league_owes_team",
    amount_cents: 2500,
    recipient_rank: null,
  },
  {
    rule_key: "weekly_low_score_penalty",
    rule_kind: "weekly_low_score_penalty",
    label: "Weekly low score penalty",
    direction: "team_owes_league",
    amount_cents: 1000,
    recipient_rank: null,
  },
];

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
  rpcError?: unknown;
} = {}) {
  const seasonQuery = queryBuilder(seasonExists ? { league_id: leagueId } : null);
  const membershipQuery = queryBuilder(commissioner ? { role: "commissioner" } : null);
  return {
    auth: {
      getClaims: vi.fn().mockResolvedValue({
        data: authenticated ? { claims: { sub: userId } } : { claims: null },
      }),
    },
    from: vi.fn((table: string) =>
      table === "seasons" ? seasonQuery : membershipQuery,
    ),
    rpc: vi.fn().mockResolvedValue({
      data: rpcError ? null : { status: "saved", rule_count: rules.length },
      error: rpcError,
    }),
  };
}

function request(body: unknown, contentType = "application/json") {
  return new Request("https://sweetnapadads.test/api/admin/financial-rules", {
    method: "PATCH",
    headers: { "content-type": contentType },
    body: JSON.stringify(body),
  });
}

describe("PATCH /api/admin/financial-rules", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(createClient).mockResolvedValue(client() as never);
  });

  it("rejects non-JSON and malformed rule bodies", async () => {
    expect((await PATCH(request({ season_id: seasonId, rules }, "text/plain"))).status).toBe(400);
    const malformed = await PATCH(request({ season_id: seasonId, rules: [] }));
    expect(await malformed.json()).toEqual({ error: "invalid_request" });
    expect(createClient).not.toHaveBeenCalled();
  });

  it("requires a verified commissioner identity", async () => {
    vi.mocked(createClient).mockResolvedValue(client({ authenticated: false }) as never);
    const unauthenticated = await PATCH(request({ season_id: seasonId, rules }));
    expect(unauthenticated.status).toBe(401);

    vi.mocked(createClient).mockResolvedValue(client({ commissioner: false }) as never);
    const forbidden = await PATCH(request({ season_id: seasonId, rules }));
    expect(forbidden.status).toBe(403);
  });

  it("does not reveal a season hidden by RLS", async () => {
    vi.mocked(createClient).mockResolvedValue(client({ seasonExists: false }) as never);
    const response = await PATCH(request({ season_id: seasonId, rules }));
    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ error: "season_not_found" });
  });

  it("passes the complete validated batch to the audited RPC", async () => {
    const supabase = client();
    vi.mocked(createClient).mockResolvedValue(supabase as never);
    const response = await PATCH(request({ season_id: seasonId, rules }));

    expect(await response.json()).toEqual({
      status: "saved",
      season_id: seasonId,
      rule_count: 2,
    });
    expect(supabase.rpc).toHaveBeenCalledWith("set_season_financial_rules", {
      target_season_id: seasonId,
      target_rules: rules,
    });
  });

  it("redacts database and unexpected server details", async () => {
    vi.mocked(createClient).mockResolvedValue(
      client({ rpcError: new Error("private constraint") }) as never,
    );
    const rejected = await PATCH(request({ season_id: seasonId, rules }));
    expect(await rejected.json()).toEqual({ error: "rules_rejected" });

    vi.mocked(createClient).mockRejectedValue(new Error("private environment"));
    const failed = await PATCH(request({ season_id: seasonId, rules }));
    expect(await failed.json()).toEqual({ error: "save_failed" });
  });
});
