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
  settings?: {
    scheduleSettings?: {
      matchupPeriodCount?: unknown;
    };
  };
  schedule?: unknown;
  teams?: unknown;
};

export type EspnMatchupSide = {
  teamId?: unknown;
  totalPoints?: unknown;
};

export type EspnScheduleItem = {
  id?: unknown;
  matchupPeriodId?: unknown;
  playoffTierType?: unknown;
  winner?: unknown;
  home?: EspnMatchupSide;
  away?: EspnMatchupSide;
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

export type NormalizedEspnResult = {
  season_team_id: string;
  opponent_season_team_id: string;
  espn_team_id: number;
  score: number;
  result: "win" | "loss" | "tie";
  source_key: string;
};

export type NormalizedEspnMatchup = {
  espn_matchup_id: number;
  week: number;
  phase: "regular_season" | "postseason";
  source_key: string;
  source_updated_at: string | null;
  results: [NormalizedEspnResult, NormalizedEspnResult];
};
