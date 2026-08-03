import { describe, expect, it } from "vitest";

import { parseMessageDraftRequest } from "@/lib/messages/input";

const valid = {
  season_id: "11111111-1111-4111-8111-111111111111",
  week: 9,
  selection: {
    includeStandings: true,
    includeResults: true,
    includeAwards: false,
  },
  notes: "Mention the close race.",
  tone: "friendly",
  length: "medium",
};

describe("parseMessageDraftRequest", () => {
  it("accepts the bounded composer request", () => {
    expect(parseMessageDraftRequest(valid)).toMatchObject({
      seasonId: valid.season_id,
      week: 9,
      tone: "friendly",
    });
  });

  it("rejects malformed, oversized, or unsupported input", () => {
    expect(parseMessageDraftRequest({ ...valid, week: 31 })).toBeNull();
    expect(parseMessageDraftRequest({ ...valid, notes: "x".repeat(1_201) })).toBeNull();
    expect(parseMessageDraftRequest({ ...valid, tone: "hostile" })).toBeNull();
    expect(parseMessageDraftRequest({ ...valid, selection: {} })).toBeNull();
  });
});
