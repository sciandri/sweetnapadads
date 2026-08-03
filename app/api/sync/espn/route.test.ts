import { afterAll, beforeEach, describe, expect, it, vi } from "vitest";

import {
  fetchEspnStandings,
  readEspnConfig,
} from "@/lib/integrations/espn/client";
import { ingestEspnStandings } from "@/lib/integrations/espn/ingest";
import { EspnStandingsError } from "@/lib/integrations/espn/standings";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

import { POST } from "./route";

vi.mock("@/lib/integrations/espn/client", () => ({
  fetchEspnStandings: vi.fn(),
  readEspnConfig: vi.fn(),
}));
vi.mock("@/lib/integrations/espn/ingest", () => ({
  ingestEspnStandings: vi.fn(),
}));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: vi.fn() }));
vi.mock("@/lib/supabase/server", () => ({ createClient: vi.fn() }));
vi.mock("@/lib/operations/telemetry", () => ({ operationalEvent: vi.fn() }));

const seasonId = "11111111-1111-4111-8111-111111111111";
const leagueId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const originalSyncSecret = process.env.SYNC_SECRET;

type QueryResult = { data: unknown; error: unknown };
type TeamRow = { id: string; espn_team_id: number | null };

function queryBuilder(result: QueryResult) {
  const builder = {
    select: vi.fn(),
    eq: vi.fn(),
    order: vi.fn(),
    maybeSingle: vi.fn(),
  };
  builder.select.mockReturnValue(builder);
  builder.eq.mockReturnValue(builder);
  builder.order.mockResolvedValue(result);
  builder.maybeSingle.mockResolvedValue(result);
  return builder;
}

function seasonTeams(count: number): TeamRow[] {
  return Array.from({ length: count }, (_, index) => ({
    id: `season-team-${index + 1}`,
    espn_team_id: index + 1,
  }));
}

function adminClient(teamRows: TeamRow[] = seasonTeams(12), seasonExists = true) {
  const seasonQuery = queryBuilder({
    data: seasonExists ? { id: seasonId, league_id: leagueId, year: 2026 } : null,
    error: null,
  });
  const teamsQuery = queryBuilder({ data: teamRows, error: null });
  return {
    from: vi.fn((table: string) =>
      table === "seasons" ? seasonQuery : teamsQuery,
    ),
    rpc: vi.fn(),
  };
}

function callerClient({
  authenticated = true,
  commissioner = true,
}: {
  authenticated?: boolean;
  commissioner?: boolean;
} = {}) {
  const membershipQuery = queryBuilder({
    data: commissioner ? { role: "commissioner" } : null,
    error: null,
  });
  return {
    auth: {
      getClaims: vi.fn().mockResolvedValue({
        data: authenticated ? { claims: { sub: userId } } : { claims: null },
      }),
    },
    from: vi.fn(() => membershipQuery),
  };
}

function request(
  headers: Record<string, string> = {},
  body: unknown = { season_id: seasonId },
) {
  return new Request("https://sweetnapadads.test/api/sync/espn", {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

describe("POST /api/sync/espn", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    process.env.SYNC_SECRET = "automation-secret";
    vi.mocked(createAdminClient).mockReturnValue(adminClient() as never);
    vi.mocked(createClient).mockResolvedValue(callerClient() as never);
    vi.mocked(readEspnConfig).mockReturnValue({
      leagueId: 999,
      s2: "private-s2",
      swid: "{private-swid}",
    });
    vi.mocked(fetchEspnStandings).mockResolvedValue({
      endpointPath: "/redacted",
      fetchedAt: "2026-07-31T00:00:00.000Z",
      httpStatus: 200,
      payload: { id: 999, seasonId: 2026, teams: [] },
      rawText: "{}",
    });
    vi.mocked(ingestEspnStandings).mockResolvedValue({
      status: "recorded",
      matchup_count: 80,
      award_week_count: 14,
      pending_tie_weeks: [7],
    } as never);
  });

  it("rejects malformed requests before accessing credentials or data", async () => {
    const response = await POST(request({}, { season_id: "2026" }));

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_request" });
    expect(createAdminClient).not.toHaveBeenCalled();
    expect(readEspnConfig).not.toHaveBeenCalled();
  });

  it("requires JSON so browser forms cannot trigger a session mutation", async () => {
    const response = await POST(
      new Request("https://sweetnapadads.test/api/sync/espn", {
        method: "POST",
        headers: { "content-type": "text/plain" },
        body: JSON.stringify({ season_id: seasonId }),
      }),
    );

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_request" });
    expect(createClient).not.toHaveBeenCalled();
  });

  it("requires authentication when the automation secret is absent or wrong", async () => {
    vi.mocked(createClient).mockResolvedValue(
      callerClient({ authenticated: false }) as never,
    );

    const response = await POST(
      request({ authorization: "Bearer incorrect-secret" }),
    );

    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unauthorized" });
    expect(createAdminClient).not.toHaveBeenCalled();
  });

  it("requires an active commissioner membership for session callers", async () => {
    vi.mocked(createClient).mockResolvedValue(
      callerClient({ commissioner: false }) as never,
    );

    const response = await POST(request());

    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({ error: "forbidden" });
    expect(fetchEspnStandings).not.toHaveBeenCalled();
  });

  it("accepts the automation bearer secret without a browser session", async () => {
    const response = await POST(
      request({ authorization: "Bearer automation-secret" }),
    );

    expect(response.status).toBe(200);
    expect(createClient).not.toHaveBeenCalled();
    expect(await response.json()).toEqual({
      status: "recorded",
      season_id: seasonId,
      team_count: 12,
      matchup_count: 80,
      award_week_count: 14,
      pending_tie_weeks: [7],
    });
  });

  it("passes all twelve season mappings and the caller idempotency key", async () => {
    const response = await POST(request({ "idempotency-key": "sync:2026:01" }));

    expect(response.status).toBe(200);
    expect(fetchEspnStandings).toHaveBeenCalledWith(
      2026,
      expect.objectContaining({ leagueId: 999 }),
    );
    expect(ingestEspnStandings).toHaveBeenCalledWith(
      expect.objectContaining({
        leagueId,
        seasonId,
        seasonYear: 2026,
        idempotencyKey: "sync:2026:01",
        mappings: expect.arrayContaining([
          { espnTeamId: 12, seasonTeamId: "season-team-12" },
        ]),
      }),
    );
  });

  it("fails closed before fetching when an active team is unmapped", async () => {
    vi.mocked(createAdminClient).mockReturnValue(
      adminClient([{ id: "season-team-1", espn_team_id: null }]) as never,
    );

    const response = await POST(request());

    expect(response.status).toBe(409);
    expect(await response.json()).toEqual({ error: "team_mapping_incomplete" });
    expect(fetchEspnStandings).not.toHaveBeenCalled();
  });

  it("returns stable configuration and upstream errors without details", async () => {
    vi.mocked(readEspnConfig).mockImplementation(() => {
      throw new Error("ESPN_S2 contains a private value");
    });
    const configurationResponse = await POST(request());
    expect(configurationResponse.status).toBe(503);
    expect(await configurationResponse.json()).toEqual({
      error: "integration_not_configured",
    });

    vi.mocked(readEspnConfig).mockReturnValue({
      leagueId: 999,
      s2: "private-s2",
      swid: "{private-swid}",
    });
    vi.mocked(fetchEspnStandings).mockRejectedValue(
      new Error("provider body with private data"),
    );
    const upstreamResponse = await POST(request());
    expect(upstreamResponse.status).toBe(502);
    expect(await upstreamResponse.json()).toEqual({ error: "upstream_failed" });
  });

  it("returns a stable conflict while ESPN has no official preseason order", async () => {
    vi.mocked(ingestEspnStandings).mockRejectedValue(
      new EspnStandingsError(
        "standings_unavailable",
        "private upstream explanation",
      ),
    );

    const response = await POST(request());

    expect(response.status).toBe(409);
    expect(await response.json()).toEqual({ error: "standings_unavailable" });
  });

  it("does not expose persistence errors", async () => {
    vi.mocked(ingestEspnStandings).mockRejectedValue(
      new Error("database connection details"),
    );

    const response = await POST(request());

    expect(response.status).toBe(500);
    expect(await response.json()).toEqual({ error: "ingestion_failed" });
  });

  it("returns not found only after the caller is authenticated", async () => {
    vi.mocked(createAdminClient).mockReturnValue(adminClient([], false) as never);

    const response = await POST(request());

    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ error: "season_not_found" });
  });

  it("reports missing server database configuration without details", async () => {
    vi.mocked(createAdminClient).mockImplementation(() => {
      throw new Error("server configuration details");
    });

    const response = await POST(request());

    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({
      error: "integration_not_configured",
    });
  });
});

afterAll(() => {
  if (originalSyncSecret === undefined) {
    delete process.env.SYNC_SECRET;
  } else {
    process.env.SYNC_SECRET = originalSyncSecret;
  }
});
