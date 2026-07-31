import { describe, expect, it } from "vitest";

import {
  buildStandingRows,
  formatCaptureTime,
  formatPoints,
} from "./view";

describe("member standings view", () => {
  it("uses ESPN's supplied official rank as the only display order", () => {
    const rows = buildStandingRows(
      [
        {
          season_team_id: "team-b",
          official_rank: 2,
          record_summary: "7-3",
          wins: 7,
          losses: 3,
          ties: 0,
          points_for: 1100.25,
          points_against: 1000,
          streak: "W2",
          captured_at: "2026-11-03T12:00:01Z",
          scoring_period: 10,
        },
        {
          season_team_id: "team-a",
          official_rank: 1,
          record_summary: "6-4",
          wins: 6,
          losses: 4,
          ties: 0,
          points_for: 900,
          points_against: 850,
          streak: "L1",
          captured_at: "2026-11-03T12:00:01Z",
          scoring_period: 10,
        },
      ],
      [
        { id: "team-a", name: "Napa A", abbreviation: "NPA" },
        { id: "team-b", name: "Napa B", abbreviation: null },
      ],
    );

    expect(rows.map(({ official_rank, team_name }) => [official_rank, team_name])).toEqual([
      [1, "Napa A"],
      [2, "Napa B"],
    ]);
  });

  it("formats fantasy points without losing hundredths", () => {
    expect(formatPoints(1234.5)).toBe("1,234.50");
  });

  it("renders a stable Pacific capture time and handles invalid evidence", () => {
    expect(formatCaptureTime("2026-11-03T12:00:01Z")).toContain("Nov 3, 2026");
    expect(formatCaptureTime("not-a-date")).toBe("Capture time unavailable");
  });
});
