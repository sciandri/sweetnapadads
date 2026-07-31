export type CurrentStandingRecord = {
  season_team_id: string;
  official_rank: number;
  record_summary: string;
  wins: number;
  losses: number;
  ties: number;
  points_for: number;
  points_against: number;
  streak: string | null;
  captured_at: string;
  scoring_period: number | null;
};

export type SeasonTeamLabel = {
  id: string;
  name: string;
  abbreviation: string | null;
};

export type StandingRow = CurrentStandingRecord & {
  team_name: string;
  abbreviation: string | null;
};

export function buildStandingRows(
  standings: CurrentStandingRecord[],
  teams: SeasonTeamLabel[],
): StandingRow[] {
  const labels = new Map(teams.map((team) => [team.id, team]));

  return standings
    .map((standing) => {
      const team = labels.get(standing.season_team_id);

      return {
        ...standing,
        team_name: team?.name ?? "Mapped league team",
        abbreviation: team?.abbreviation ?? null,
      };
    })
    .sort((left, right) => left.official_rank - right.official_rank);
}

export function formatPoints(value: number): string {
  return new Intl.NumberFormat("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

export function formatCaptureTime(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.valueOf())) return "Capture time unavailable";

  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZone: "America/Los_Angeles",
    timeZoneName: "short",
  }).format(date);
}
