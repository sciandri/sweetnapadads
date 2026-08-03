import { afterEach, describe, expect, it, vi } from "vitest";

import { operationalEvent } from "./telemetry";

describe("operationalEvent", () => {
  afterEach(() => vi.restoreAllMocks());

  it("writes structured metadata while dropping sensitive fields", () => {
    const info = vi.spyOn(console, "info").mockImplementation(() => undefined);
    operationalEvent("espn_sync_completed", {
      season_id: "season-1",
      team_count: 12,
      authorization: "private",
      raw_payload: "private",
    });
    const event = JSON.parse(String(info.mock.calls[0]?.[0]));
    expect(event).toMatchObject({
      level: "info",
      event: "espn_sync_completed",
      season_id: "season-1",
      team_count: 12,
    });
    expect(event).not.toHaveProperty("authorization");
    expect(event).not.toHaveProperty("raw_payload");
  });
});
