import { beforeEach, describe, expect, it, vi } from "vitest";

import { createClient } from "@/lib/supabase/server";

import { PATCH } from "./route";

vi.mock("@/lib/supabase/server", () => ({ createClient: vi.fn() }));

const seasonId = "11111111-1111-4111-8111-111111111111";
const leagueId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";

function queryBuilder(data: unknown, error: unknown = null) {
  const builder = {
    select: vi.fn(),
    eq: vi.fn(),
    maybeSingle: vi.fn(),
  };
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
  const seasonQuery = queryBuilder(
    seasonExists ? { league_id: leagueId } : null,
  );
  const membershipQuery = queryBuilder(
    commissioner ? { role: "commissioner" } : null,
  );
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
      data: rpcError ? null : { status: "saved", mapped_count: 12 },
      error: rpcError,
    }),
  };
}

function mappings(count: number) {
  return Array.from({ length: count }, (_, index) => ({
    season_team_id: `00000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`,
    espn_team_id: index + 1,
  }));
}

function request(body: unknown, contentType = "application/json") {
  return new Request("https://sweetnapadads.test/api/admin/espn-mappings", {
    method: "PATCH",
    headers: { "content-type": contentType },
    body: JSON.stringify(body),
  });
}

describe("PATCH /api/admin/espn-mappings", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(createClient).mockResolvedValue(client() as never);
  });

  it("rejects non-JSON and malformed mapping bodies", async () => {
    const nonJson = await PATCH(
      request({ season_id: seasonId, mappings: mappings(1) }, "text/plain"),
    );
    expect(nonJson.status).toBe(400);

    const malformed = await PATCH(
      request({ season_id: seasonId, mappings: [] }),
    );
    expect(malformed.status).toBe(400);
    expect(await malformed.json()).toEqual({ error: "invalid_request" });
    expect(createClient).not.toHaveBeenCalled();
  });

  it("requires a verified Supabase identity", async () => {
    vi.mocked(createClient).mockResolvedValue(
      client({ authenticated: false }) as never,
    );

    const response = await PATCH(
      request({ season_id: seasonId, mappings: mappings(1) }),
    );

    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unauthorized" });
  });

  it("does not reveal a season hidden by RLS", async () => {
    vi.mocked(createClient).mockResolvedValue(client({ seasonExists: false }) as never);

    const response = await PATCH(
      request({ season_id: seasonId, mappings: mappings(1) }),
    );

    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ error: "season_not_found" });
  });

  it("requires an active commissioner membership", async () => {
    vi.mocked(createClient).mockResolvedValue(client({ commissioner: false }) as never);

    const response = await PATCH(
      request({ season_id: seasonId, mappings: mappings(1) }),
    );

    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({ error: "forbidden" });
  });

  it("sends the complete twelve-team batch to the atomic RPC", async () => {
    const supabase = client();
    vi.mocked(createClient).mockResolvedValue(supabase as never);
    const teamMappings = mappings(12);

    const response = await PATCH(
      request({ season_id: seasonId, mappings: teamMappings }),
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      status: "saved",
      season_id: seasonId,
      mapped_count: 12,
    });
    expect(supabase.rpc).toHaveBeenCalledWith(
      "set_espn_season_team_mappings",
      {
        target_season_id: seasonId,
        target_mappings: teamMappings,
      },
    );
  });

  it("redacts mapping rejection and unexpected server details", async () => {
    vi.mocked(createClient).mockResolvedValue(
      client({ rpcError: new Error("private constraint detail") }) as never,
    );
    const rejected = await PATCH(
      request({ season_id: seasonId, mappings: mappings(1) }),
    );
    expect(rejected.status).toBe(409);
    expect(await rejected.json()).toEqual({ error: "mapping_rejected" });

    vi.mocked(createClient).mockRejectedValue(
      new Error("private server configuration"),
    );
    const failed = await PATCH(
      request({ season_id: seasonId, mappings: mappings(1) }),
    );
    expect(failed.status).toBe(500);
    expect(await failed.json()).toEqual({ error: "save_failed" });
  });
});
