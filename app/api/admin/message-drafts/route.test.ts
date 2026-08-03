import { beforeEach, describe, expect, it, vi } from "vitest";

import { generateMessageDrafts } from "@/lib/messages/generator";
import { createClient } from "@/lib/supabase/server";

import { POST } from "./route";

vi.mock("@/lib/messages/generator", async (importOriginal) => {
  const original = await importOriginal<typeof import("@/lib/messages/generator")>();
  return { ...original, generateMessageDrafts: vi.fn() };
});
vi.mock("@/lib/supabase/server", () => ({ createClient: vi.fn() }));
vi.mock("@/lib/operations/telemetry", () => ({ operationalEvent: vi.fn() }));

const body = {
  season_id: "11111111-1111-4111-8111-111111111111",
  week: 9,
  selection: { includeStandings: true, includeResults: true, includeAwards: true },
  notes: "Mention the race.",
  tone: "friendly",
  length: "medium",
};

function request(value: unknown) {
  return new Request("https://sweetnapadads.test/api/admin/message-drafts", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(value),
  });
}

function client({ authenticated = true, commissioner = true, contextError = null } = {}) {
  let table = "";
  const query = { select: vi.fn(), eq: vi.fn(), maybeSingle: vi.fn() };
  query.select.mockReturnValue(query);
  query.eq.mockReturnValue(query);
  query.maybeSingle.mockImplementation(async () => table === "seasons"
    ? { data: { league_id: "league-1" }, error: null }
    : { data: commissioner ? { role: "commissioner" } : null, error: null });
  return {
    auth: { getClaims: vi.fn().mockResolvedValue({ data: authenticated ? { claims: { sub: "user-1" } } : { claims: null } }) },
    from: vi.fn((name: string) => { table = name; return query; }),
    rpc: vi.fn().mockResolvedValue({ data: contextError ? null : { league: { id: "league-1" } }, error: contextError }),
  };
}

describe("POST /api/admin/message-drafts", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    process.env.OPENAI_API_KEY = "server-only-key";
    vi.mocked(createClient).mockResolvedValue(client() as never);
    vi.mocked(generateMessageDrafts).mockResolvedValue(["One", "Two", "Three"]);
  });

  it("rejects invalid input before authentication", async () => {
    expect((await POST(request({ ...body, week: 31 }))).status).toBe(400);
    expect(createClient).not.toHaveBeenCalled();
  });

  it("requires an authenticated commissioner", async () => {
    vi.mocked(createClient).mockResolvedValue(client({ authenticated: false }) as never);
    expect((await POST(request(body))).status).toBe(401);
    vi.mocked(createClient).mockResolvedValue(client({ commissioner: false }) as never);
    expect((await POST(request(body))).status).toBe(403);
  });

  it("returns a stable configuration error when the key is absent", async () => {
    delete process.env.OPENAI_API_KEY;
    expect(await (await POST(request(body))).json()).toEqual({ error: "generation_not_configured" });
    expect(generateMessageDrafts).not.toHaveBeenCalled();
  });

  it("assembles server context and returns exactly three drafts", async () => {
    const supabase = client();
    vi.mocked(createClient).mockResolvedValue(supabase as never);
    const response = await POST(request(body));
    expect(await response.json()).toEqual({ drafts: ["One", "Two", "Three"] });
    expect(supabase.rpc).toHaveBeenCalledWith("get_commissioner_message_context", {
      target_season_id: body.season_id,
      target_week: 9,
    });
    expect(generateMessageDrafts).toHaveBeenCalledWith(expect.objectContaining({ apiKey: "server-only-key" }));
  });
});
