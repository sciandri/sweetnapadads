export type StandingContext = {
  rank: number;
  team_key: string;
  team_name: string;
  espn_team_id: number;
  record: string;
  wins: number;
  losses: number;
  ties: number;
  points_for: number;
  points_against: number;
  streak: string | null;
  playoff_seed: number | null;
};

export type MatchupTeamContext = {
  team_key: string;
  team_name: string;
  score: number;
  result: "win" | "loss" | "tie";
  notes: string | null;
};

export type MatchupContext = {
  week: number;
  phase: "regular_season" | "postseason";
  source_key: string;
  teams: MatchupTeamContext[];
};

export type AwardContext = {
  week: number;
  high_team_key: string;
  high_team_name: string;
  high_score: number;
  low_team_key: string;
  low_team_name: string;
  low_score: number;
};

export type CommissionerMessageContext = {
  league: {
    id: string;
    name: string;
  };
  season: {
    id: string;
    year: number;
    name: string;
  };
  selected_week: number;
  standings: {
    source: "espn";
    available: boolean;
    snapshot_id: string | null;
    captured_at: string | null;
    scoring_period: number | null;
    official_order: StandingContext[];
  };
  results: MatchupContext[];
  awards: AwardContext[];
  financial_context_included: false;
};

export type MessageContextSelection = {
  includeStandings: boolean;
  includeResults: boolean;
  includeAwards: boolean;
};

export type MessageTone = "concise" | "friendly" | "energetic";
export type MessageLength = "short" | "medium" | "long";
