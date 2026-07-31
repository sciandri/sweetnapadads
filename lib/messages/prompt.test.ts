import { describe, expect, it } from "vitest";

import type { CommissionerMessageContext } from "@/lib/messages/context";
import {
  buildMessageDraftPrompt,
  MESSAGE_DRAFT_SYSTEM_INSTRUCTIONS,
} from "@/lib/messages/prompt";

const context: CommissionerMessageContext = {
  league: { id: "league-1", name: "Sweet Looking Napa Dads" },
  season: { id: "season-1", year: 2026, name: "2026 Season" },
  selected_week: 9,
  standings: {
    source: "espn",
    available: true,
    snapshot_id: "snapshot-1",
    captured_at: "2026-11-03T12:00:01Z",
    scoring_period: 9,
    official_order: [
      {
        rank: 1,
        team_key: "official-first",
        team_name: "Official First",
        espn_team_id: 2,
        record: "5-4",
        wins: 5,
        losses: 4,
        ties: 0,
        points_for: 900.3,
        points_against: 899.1,
        streak: "W2",
        playoff_seed: 1,
      },
    ],
  },
  results: [
    {
      week: 9,
      phase: "regular_season",
      source_key: "espn:matchup:9:1:2",
      teams: [
        {
          team_key: "official-first",
          team_name: "Official First",
          score: 111.11,
          result: "win",
          notes: null,
        },
      ],
    },
  ],
  awards: [],
  financial_context_included: false,
};

describe("commissioner message prompt", () => {
  it("preserves selected verified ESPN and result context", () => {
    const prompt = buildMessageDraftPrompt({
      context,
      selection: {
        includeStandings: true,
        includeResults: true,
        includeAwards: false,
      },
      notes: "Mention the close race.",
      tone: "energetic",
      length: "medium",
    });

    expect(prompt).toContain('"source": "espn"');
    expect(prompt).toContain('"rank": 1');
    expect(prompt).toContain('"score": 111.11');
    expect(prompt).toContain("Mention the close race.");
    expect(prompt).not.toContain('"awards"');
  });

  it("excludes unselected fact groups and always excludes finance", () => {
    const prompt = buildMessageDraftPrompt({
      context,
      selection: {
        includeStandings: false,
        includeResults: false,
        includeAwards: false,
      },
      notes: "Draft night reminder.",
      tone: "concise",
      length: "short",
    });

    expect(prompt).not.toContain('"official_order"');
    expect(prompt).not.toContain('"source_key"');
    expect(prompt).toContain('"financial_context_included": false');
  });

  it("forbids the model from recalculating standings or inventing facts", () => {
    expect(MESSAGE_DRAFT_SYSTEM_INSTRUCTIONS).toContain(
      "never calculate, infer, or reorder",
    );
    expect(MESSAGE_DRAFT_SYSTEM_INSTRUCTIONS).toContain(
      "omit it instead of guessing",
    );
  });
});
