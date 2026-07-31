import { describe, expect, it } from "vitest";

import {
  bearerToken,
  parseEspnSyncRequest,
  secretsMatch,
} from "@/lib/integrations/espn/security";

const seasonId = "11111111-1111-4111-8111-111111111111";

describe("ESPN synchronization request security", () => {
  it("compares configured automation secrets without accepting missing values", () => {
    expect(secretsMatch("correct", "correct")).toBe(true);
    expect(secretsMatch("incorrect", "correct")).toBe(false);
    expect(secretsMatch(null, "correct")).toBe(false);
    expect(secretsMatch("correct", undefined)).toBe(false);
  });

  it("accepts only a single bearer credential", () => {
    expect(bearerToken("Bearer secret-value")).toBe("secret-value");
    expect(bearerToken("bearer secret-value")).toBe("secret-value");
    expect(bearerToken("Basic secret-value")).toBeNull();
    expect(bearerToken("Bearer two values")).toBeNull();
  });

  it("validates the season UUID and optional idempotency key", () => {
    expect(
      parseEspnSyncRequest({ season_id: seasonId }, "run:2026-week-01"),
    ).toEqual({
      seasonId,
      idempotencyKey: "run:2026-week-01",
    });
  });

  it("rejects malformed bodies and season identifiers", () => {
    expect(parseEspnSyncRequest(null, null)).toBeNull();
    expect(parseEspnSyncRequest([], null)).toBeNull();
    expect(parseEspnSyncRequest({}, null)).toBeNull();
    expect(parseEspnSyncRequest({ season_id: "2026" }, null)).toBeNull();
  });

  it("rejects unsafe or oversized idempotency keys", () => {
    expect(
      parseEspnSyncRequest({ season_id: seasonId }, "spaces are unsafe"),
    ).toBeNull();
    expect(
      parseEspnSyncRequest({ season_id: seasonId }, "a".repeat(201)),
    ).toBeNull();
  });
});
