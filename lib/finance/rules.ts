const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const KEY_PATTERN = /^[a-z][a-z0-9_]{0,49}$/;

export const financialRuleKinds = [
  "weekly_high_score",
  "weekly_low_score_penalty",
  "placement_payout",
  "season_award",
  "penalty",
] as const;

export type FinancialRuleKind = (typeof financialRuleKinds)[number];
export type FinancialRuleInput = {
  rule_key: string;
  rule_kind: FinancialRuleKind;
  label: string;
  direction: "league_owes_team" | "team_owes_league";
  amount_cents: number;
  recipient_rank: number | null;
};

function parseRule(value: unknown): FinancialRuleInput | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const rule = value as Record<string, unknown>;
  const kind = rule.rule_kind;
  const isKind = financialRuleKinds.includes(kind as FinancialRuleKind);
  const rank = rule.recipient_rank ?? null;
  if (
    typeof rule.rule_key !== "string" ||
    !KEY_PATTERN.test(rule.rule_key) ||
    !isKind ||
    typeof rule.label !== "string" ||
    rule.label.trim() !== rule.label ||
    rule.label.length < 1 ||
    rule.label.length > 100 ||
    !Number.isSafeInteger(rule.amount_cents) ||
    Number(rule.amount_cents) <= 0 ||
    (rank !== null && (!Number.isInteger(rank) || Number(rank) <= 0))
  ) {
    return null;
  }

  const payout = ["weekly_high_score", "placement_payout", "season_award"].includes(
    String(kind),
  );
  const direction = payout ? "league_owes_team" : "team_owes_league";
  if (rule.direction !== direction) return null;
  if ((kind === "placement_payout") !== (rank !== null)) return null;

  return {
    rule_key: rule.rule_key,
    rule_kind: kind as FinancialRuleKind,
    label: rule.label,
    direction,
    amount_cents: Number(rule.amount_cents),
    recipient_rank: rank === null ? null : Number(rank),
  };
}

export function parseFinancialRuleUpdate(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const body = value as Record<string, unknown>;
  if (
    typeof body.season_id !== "string" ||
    !UUID_PATTERN.test(body.season_id) ||
    !Array.isArray(body.rules) ||
    body.rules.length < 2 ||
    body.rules.length > 100
  ) {
    return null;
  }

  const rules = body.rules.map(parseRule);
  if (rules.some((rule) => rule === null)) return null;
  const parsed = rules as FinancialRuleInput[];
  if (new Set(parsed.map((rule) => rule.rule_key)).size !== parsed.length) return null;
  const placementRanks = parsed
    .filter((rule) => rule.rule_kind === "placement_payout")
    .map((rule) => rule.recipient_rank);
  if (new Set(placementRanks).size !== placementRanks.length) return null;
  if (
    !parsed.some(
      (rule) =>
        rule.rule_key === "weekly_high_score" &&
        rule.rule_kind === "weekly_high_score",
    ) ||
    !parsed.some(
      (rule) =>
        rule.rule_key === "weekly_low_score_penalty" &&
        rule.rule_kind === "weekly_low_score_penalty",
    )
  ) {
    return null;
  }

  return { seasonId: body.season_id, rules: parsed };
}
