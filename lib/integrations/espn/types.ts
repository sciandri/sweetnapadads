export type EspnOverallRecord = {
  wins?: unknown;
  losses?: unknown;
  ties?: unknown;
  pointsFor?: unknown;
  pointsAgainst?: unknown;
  streakLength?: unknown;
  streakType?: unknown;
};

export type EspnTeam = {
  id?: unknown;
  playoffSeed?: unknown;
  rankCalculatedFinal?: unknown;
  points?: unknown;
  record?: {
    overall?: EspnOverallRecord;
  };
};

export type EspnLeaguePayload = {
  id?: unknown;
  seasonId?: unknown;
  scoringPeriodId?: unknown;
  status?: {
    finalScoringPeriod?: unknown;
    latestScoringPeriod?: unknown;
    standingsUpdateDate?: unknown;
  };
  teams?: unknown;
};

export type EspnTeamMapping = {
  espnTeamId: number;
  seasonTeamId: string;
};

export type NormalizedEspnStanding = {
  season_team_id: string;
  espn_team_id: number;
  official_rank: number;
  playoff_seed: number | null;
  wins: number;
  losses: number;
  ties: number;
  points_for: number;
  points_against: number;
  streak: string | null;
  record_summary: string;
  source_record: Record<string, unknown>;
};
