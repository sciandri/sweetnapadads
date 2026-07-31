export type CompetitionMatchupRecord = {
  id: string;
  week: number;
  phase: "regular_season" | "postseason";
  source_type: "manual" | "espn" | "import" | "system";
};

export type WeeklyResultRecord = {
  matchup_id: string;
  season_team_id: string;
  opponent_season_team_id: string;
  score: number;
  result: "win" | "loss" | "tie";
};

export type WeeklyAwardRecord = {
  week: number;
  high_score_season_team_id: string;
  high_score: number;
  low_score_season_team_id: string;
  low_score: number;
};

export type CompetitionTeamLabel = {
  id: string;
  name: string;
  abbreviation: string | null;
};

export type ResultRow = WeeklyResultRecord & {
  team_name: string;
  abbreviation: string | null;
};

export type MatchupCard = CompetitionMatchupRecord & {
  results: ResultRow[];
  complete: boolean;
};

export type AwardSummary = {
  high: { team_name: string; score: number };
  low: { team_name: string; score: number };
};

export type CompetitionWeek = {
  week: number;
  phase: "regular_season" | "postseason";
  matchups: MatchupCard[];
  award: AwardSummary | null;
};

const resultOrder = { win: 0, tie: 1, loss: 2 } as const;

function teamName(
  teamId: string,
  labels: Map<string, CompetitionTeamLabel>,
) {
  return labels.get(teamId)?.name ?? "League team";
}

export function buildCompetitionWeeks(
  matchups: CompetitionMatchupRecord[],
  results: WeeklyResultRecord[],
  awards: WeeklyAwardRecord[],
  teams: CompetitionTeamLabel[],
): CompetitionWeek[] {
  const labels = new Map(teams.map((team) => [team.id, team]));
  const resultsByMatchup = new Map<string, WeeklyResultRecord[]>();

  for (const result of results) {
    const current = resultsByMatchup.get(result.matchup_id) ?? [];
    current.push(result);
    resultsByMatchup.set(result.matchup_id, current);
  }

  const awardByWeek = new Map(awards.map((award) => [award.week, award]));
  const weeks = new Map<number, CompetitionWeek>();

  for (const matchup of matchups) {
    const matchupResults = (resultsByMatchup.get(matchup.id) ?? [])
      .map((result) => ({
        ...result,
        team_name: teamName(result.season_team_id, labels),
        abbreviation: labels.get(result.season_team_id)?.abbreviation ?? null,
      }))
      .sort((left, right) =>
        resultOrder[left.result] - resultOrder[right.result]
        || right.score - left.score
        || left.team_name.localeCompare(right.team_name),
      );

    const current = weeks.get(matchup.week) ?? {
      week: matchup.week,
      phase: matchup.phase,
      matchups: [],
      award: null,
    };
    current.matchups.push({
      ...matchup,
      results: matchupResults,
      complete: matchupResults.length === 2,
    });
    weeks.set(matchup.week, current);
  }

  for (const week of weeks.values()) {
    week.matchups.sort((left, right) => {
      const leftName = left.results[0]?.team_name ?? left.id;
      const rightName = right.results[0]?.team_name ?? right.id;
      return leftName.localeCompare(rightName);
    });

    const award = awardByWeek.get(week.week);
    if (award) {
      week.award = {
        high: {
          team_name: teamName(award.high_score_season_team_id, labels),
          score: award.high_score,
        },
        low: {
          team_name: teamName(award.low_score_season_team_id, labels),
          score: award.low_score,
        },
      };
    }
  }

  return [...weeks.values()].sort((left, right) => right.week - left.week);
}

export function formatCompetitionScore(value: number): string {
  return new Intl.NumberFormat("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}
