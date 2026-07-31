export type HistoricalSeason = {
  id: string;
  year: number;
  name: string;
  status: string;
};

export type HistoricalSeasonTeam = {
  id: string;
  team_id: string;
  season_id: string;
  name: string;
  abbreviation: string | null;
};

export type HistoricalResult = {
  matchup_id: string;
  season_id: string;
  season_team_id: string;
  opponent_season_team_id: string;
  score: number;
  result: "win" | "loss" | "tie";
};

export type HistoricalAward = {
  season_id: string;
  high_score_season_team_id: string;
  low_score_season_team_id: string;
};

export type HistoricalBalance = {
  season_id: string;
  season_team_id: string;
  balance_cents: number;
};

export type TeamSeasonHistory = {
  season_id: string;
  season_team_id: string;
  year: number;
  season_name: string;
  season_status: string;
  team_name: string;
  abbreviation: string | null;
  games: number;
  wins: number;
  losses: number;
  ties: number;
  points_for: number;
  points_against: number;
  high_score_honors: number;
  low_score_penalties: number;
  balance_cents: number;
};

export type OwnershipRecord = {
  id: string;
  owner_id: string;
  started_on: string;
  ended_on: string | null;
  is_primary: boolean;
};

export type OwnerLabel = { id: string; display_name: string };

export type OwnershipHistoryRow = OwnershipRecord & { owner_name: string };

export function buildTeamSeasonHistory(
  teamId: string,
  seasons: HistoricalSeason[],
  seasonTeams: HistoricalSeasonTeam[],
  results: HistoricalResult[],
  awards: HistoricalAward[],
  balances: HistoricalBalance[],
): TeamSeasonHistory[] {
  const seasonsById = new Map(seasons.map((season) => [season.id, season]));
  const resultByTeamAndMatchup = new Map(
    results.map((result) => [
      `${result.matchup_id}:${result.season_team_id}`,
      result,
    ]),
  );
  const balancesByTeam = new Map(
    balances.map((balance) => [balance.season_team_id, balance]),
  );

  return seasonTeams
    .filter((entry) => entry.team_id === teamId)
    .map((entry) => {
      const season = seasonsById.get(entry.season_id);
      if (!season) return null;
      const teamResults = results.filter(
        (result) => result.season_team_id === entry.id,
      );
      const pointsAgainst = teamResults.reduce((total, result) => {
        const opponent = resultByTeamAndMatchup.get(
          `${result.matchup_id}:${result.opponent_season_team_id}`,
        );
        return total + (opponent?.score ?? 0);
      }, 0);

      return {
        season_id: season.id,
        season_team_id: entry.id,
        year: season.year,
        season_name: season.name,
        season_status: season.status,
        team_name: entry.name,
        abbreviation: entry.abbreviation,
        games: teamResults.length,
        wins: teamResults.filter((result) => result.result === "win").length,
        losses: teamResults.filter((result) => result.result === "loss").length,
        ties: teamResults.filter((result) => result.result === "tie").length,
        points_for: teamResults.reduce((total, result) => total + result.score, 0),
        points_against: pointsAgainst,
        high_score_honors: awards.filter(
          (award) => award.high_score_season_team_id === entry.id,
        ).length,
        low_score_penalties: awards.filter(
          (award) => award.low_score_season_team_id === entry.id,
        ).length,
        balance_cents: balancesByTeam.get(entry.id)?.balance_cents ?? 0,
      };
    })
    .filter((item): item is TeamSeasonHistory => item !== null)
    .sort((left, right) => right.year - left.year);
}

export function buildOwnershipHistory(
  ownership: OwnershipRecord[],
  owners: OwnerLabel[],
): OwnershipHistoryRow[] {
  const ownerById = new Map(owners.map((owner) => [owner.id, owner.display_name]));
  return ownership
    .map((item) => ({
      ...item,
      owner_name: ownerById.get(item.owner_id) ?? "League owner",
    }))
    .sort((left, right) => {
      if (left.ended_on === null && right.ended_on !== null) return -1;
      if (left.ended_on !== null && right.ended_on === null) return 1;
      return right.started_on.localeCompare(left.started_on);
    });
}
