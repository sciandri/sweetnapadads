import { describe, expect, it } from "vitest";

import { parseFinancialRuleUpdate } from "./rules";

const seasonId = "11111111-1111-4111-8111-111111111111";
const weekly = [
  {
    rule_key: "weekly_high_score",
    rule_kind: "weekly_high_score",
    label: "Weekly high score",
    direction: "league_owes_team",
    amount_cents: 2500,
    recipient_rank: null,
  },
  {
    rule_key: "weekly_low_score_penalty",
    rule_kind: "weekly_low_score_penalty",
    label: "Weekly low score penalty",
    direction: "team_owes_league",
    amount_cents: 1000,
    recipient_rank: null,
  },
];

describe("financial rule input", () => {
  it("accepts configured weekly, placement, season, and penalty rules", () => {
    const parsed = parseFinancialRuleUpdate({
      season_id: seasonId,
      rules: [
        ...weekly,
        {
          rule_key: "first_place",
          rule_kind: "placement_payout",
          label: "Champion",
          direction: "league_owes_team",
          amount_cents: 80000,
          recipient_rank: 1,
        },
      ],
    });

    expect(parsed?.rules).toHaveLength(3);
  });

  it("requires both canonical weekly rules", () => {
    expect(parseFinancialRuleUpdate({ season_id: seasonId, rules: weekly.slice(0, 1) })).toBeNull();
  });

  it("rejects unsafe money and incompatible directions", () => {
    expect(
      parseFinancialRuleUpdate({
        season_id: seasonId,
        rules: [{ ...weekly[0], amount_cents: Number.MAX_SAFE_INTEGER + 1 }, weekly[1]],
      }),
    ).toBeNull();
    expect(
      parseFinancialRuleUpdate({
        season_id: seasonId,
        rules: [{ ...weekly[0], direction: "team_owes_league" }, weekly[1]],
      }),
    ).toBeNull();
  });

  it("requires unique rule keys and placement ranks", () => {
    const placement = {
      rule_key: "first_place",
      rule_kind: "placement_payout",
      label: "First",
      direction: "league_owes_team",
      amount_cents: 80000,
      recipient_rank: 1,
    };
    expect(
      parseFinancialRuleUpdate({
        season_id: seasonId,
        rules: [...weekly, placement, { ...placement, rule_key: "champion_bonus" }],
      }),
    ).toBeNull();
  });
});
