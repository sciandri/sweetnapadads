import { describe, expect, it } from "vitest";

import { parseNotificationRequest } from "./input";

const request = {
  league_id: "11111111-1111-4111-8111-111111111111",
  season_id: "22222222-2222-4222-8222-222222222222",
  kind: "announcement",
  audience: "all_members",
  title: "Draft reminder",
  body: "Bring your dues to the draft.",
};

describe("parseNotificationRequest", () => {
  it("accepts a bounded league notification", () => {
    expect(parseNotificationRequest(request)).toMatchObject({
      kind: "announcement",
      audience: "all_members",
    });
  });

  it("rejects invalid audience, whitespace, and oversized content", () => {
    expect(parseNotificationRequest({ ...request, audience: "public" })).toBeNull();
    expect(parseNotificationRequest({ ...request, title: " Draft reminder" })).toBeNull();
    expect(parseNotificationRequest({ ...request, body: "x".repeat(2_001) })).toBeNull();
  });
});
