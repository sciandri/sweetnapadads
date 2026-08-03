import { afterEach, describe, expect, it, vi } from "vitest";

import type { CommissionerMessageContext } from "@/lib/messages/context";
import { generateMessageDrafts, MessageGenerationError } from "@/lib/messages/generator";

const context = {
  league: { id: "league-1", name: "League" },
  season: { id: "season-1", year: 2026, name: "2026" },
  selected_week: 1,
  standings: { source: "espn", available: false, snapshot_id: null, captured_at: null, scoring_period: null, official_order: [] },
  results: [],
  awards: [],
  financial_context_included: false,
} satisfies CommissionerMessageContext;

const request = {
  seasonId: "11111111-1111-4111-8111-111111111111",
  week: 1,
  selection: { includeStandings: false, includeResults: false, includeAwards: false },
  notes: "Draft night is Thursday.",
  tone: "friendly" as const,
  length: "short" as const,
};

describe("generateMessageDrafts", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("uses a private, non-stored structured Responses request", async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({
      status: "completed",
      output_text: JSON.stringify({ draft_1: "One", draft_2: "Two", draft_3: "Three" }),
    })));
    vi.stubGlobal("fetch", fetchMock);

    await expect(generateMessageDrafts({ apiKey: "private-key", context, request })).resolves.toEqual(["One", "Two", "Three"]);
    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    const body = JSON.parse(String(init.body));
    expect(body).toMatchObject({
      model: "gpt-5.6-terra",
      store: false,
      reasoning: { effort: "none" },
      text: { format: { type: "json_schema", strict: true } },
    });
    expect(body.input).toContain("Draft night is Thursday.");
    expect(JSON.stringify(body)).not.toContain("private-key");
  });

  it("fails closed on upstream errors and invalid output", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("{}", { status: 500 })));
    await expect(generateMessageDrafts({ apiKey: "key", context, request })).rejects.toEqual(new MessageGenerationError("generation_failed"));

    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(JSON.stringify({ status: "completed", output_text: "{}" }))));
    await expect(generateMessageDrafts({ apiKey: "key", context, request })).rejects.toMatchObject({ code: "generation_failed" });
  });
});
