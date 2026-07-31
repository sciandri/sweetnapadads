export type ActivityTeam = { id: string; name: string };

export type ActivityMatchup = {
  id: string;
  week: number;
  phase: "regular_season" | "postseason";
  source_type: string;
};

export type ActivityResult = {
  matchup_id: string;
  season_team_id: string;
  score: number;
  result: "win" | "loss" | "tie";
};

export type ActivityAward = {
  id: string;
  week: number;
  high_score_season_team_id: string;
  high_score: number;
  low_score_season_team_id: string;
  low_score: number;
  source_type: string;
};

export type CompetitionActivityEntry = {
  id: string;
  kind: "matchup" | "award";
  week: number;
  phase: "regular_season" | "postseason";
  headline: string;
  detail: string;
  source: string;
};

export type ActivityObligation = {
  id: string;
  season_team_id: string;
  direction: "team_owes_league" | "league_owes_team";
  amount_cents: number;
  description: string;
  occurred_on: string;
};

export type ActivityPayment = {
  id: string;
  season_team_id: string;
  direction: "from_team" | "to_team";
  amount_cents: number;
  paid_on: string;
  note: string | null;
};

export type ActivityAdjustment = {
  id: string;
  season_team_id: string;
  direction: "increase_team_balance" | "decrease_team_balance";
  amount_cents: number;
  reason: string;
  occurred_on: string;
};

export type FinancialActivityEntry = {
  id: string;
  kind: "obligation" | "payment" | "adjustment";
  occurred_on: string;
  team_name: string;
  headline: string;
  direction: string;
  amount_cents: number;
};

function teamName(id: string, teams: Map<string, string>) {
  return teams.get(id) ?? "League team";
}

function score(value: number) {
  return value.toFixed(2);
}

export function buildCompetitionActivity(
  matchups: ActivityMatchup[],
  results: ActivityResult[],
  awards: ActivityAward[],
  teams: ActivityTeam[],
): CompetitionActivityEntry[] {
  const names = new Map(teams.map((team) => [team.id, team.name]));
  const entries: CompetitionActivityEntry[] = [];

  for (const matchup of matchups) {
    const rows = results
      .filter((result) => result.matchup_id === matchup.id)
      .sort((left, right) => {
        const order = { win: 0, tie: 1, loss: 2 } as const;
        return order[left.result] - order[right.result]
          || right.score - left.score
          || teamName(left.season_team_id, names).localeCompare(teamName(right.season_team_id, names));
      });
    const first = rows[0];
    const second = rows[1];
    const complete = rows.length === 2;
    const tied = complete && first.result === "tie" && second.result === "tie";
    entries.push({
      id: matchup.id,
      kind: "matchup",
      week: matchup.week,
      phase: matchup.phase,
      headline: !complete
        ? "Matchup result pending"
        : tied
          ? `${teamName(first.season_team_id, names)} tied ${teamName(second.season_team_id, names)}`
          : `${teamName(first.season_team_id, names)} defeated ${teamName(second.season_team_id, names)}`,
      detail: complete ? `${score(first.score)} – ${score(second.score)}` : "Accepted reciprocal scores are not complete.",
      source: matchup.source_type,
    });
  }

  for (const award of awards) {
    entries.push({
      id: award.id,
      kind: "award",
      week: award.week,
      phase: "regular_season",
      headline: `Week ${award.week} honors recorded`,
      detail: `High: ${teamName(award.high_score_season_team_id, names)} ${score(award.high_score)} · Low: ${teamName(award.low_score_season_team_id, names)} ${score(award.low_score)}`,
      source: award.source_type,
    });
  }

  return entries.sort((left, right) =>
    right.week - left.week
    || (left.kind === "award" ? -1 : right.kind === "award" ? 1 : 0)
    || left.headline.localeCompare(right.headline),
  );
}

export function buildFinancialActivity(
  obligations: ActivityObligation[],
  payments: ActivityPayment[],
  adjustments: ActivityAdjustment[],
  teams: ActivityTeam[],
): FinancialActivityEntry[] {
  const names = new Map(teams.map((team) => [team.id, team.name]));
  const entries: FinancialActivityEntry[] = [
    ...obligations.map((item) => ({
      id: item.id,
      kind: "obligation" as const,
      occurred_on: item.occurred_on,
      team_name: teamName(item.season_team_id, names),
      headline: item.description,
      direction: item.direction === "team_owes_league" ? "Team owes league" : "League owes team",
      amount_cents: item.amount_cents,
    })),
    ...payments.map((item) => ({
      id: item.id,
      kind: "payment" as const,
      occurred_on: item.paid_on,
      team_name: teamName(item.season_team_id, names),
      headline: item.note ?? (item.direction === "from_team" ? "Payment received" : "Payment sent"),
      direction: item.direction === "from_team" ? "Paid by team" : "Paid to team",
      amount_cents: item.amount_cents,
    })),
    ...adjustments.map((item) => ({
      id: item.id,
      kind: "adjustment" as const,
      occurred_on: item.occurred_on,
      team_name: teamName(item.season_team_id, names),
      headline: item.reason,
      direction: item.direction === "increase_team_balance" ? "Balance increased" : "Balance decreased",
      amount_cents: item.amount_cents,
    })),
  ];

  return entries.sort((left, right) =>
    right.occurred_on.localeCompare(left.occurred_on)
    || left.kind.localeCompare(right.kind)
    || left.id.localeCompare(right.id),
  );
}
