import type {
  EspnLeaguePayload,
  EspnScheduleItem,
  EspnTeamMapping,
  NormalizedEspnMatchup,
} from "@/lib/integrations/espn/types";

export class EspnMatchupsError extends Error {
  constructor(
    readonly code:
      | "invalid_payload"
      | "league_mismatch"
      | "season_mismatch"
      | "team_mapping_incomplete",
    message: string,
  ) {
    super(message);
    this.name = "EspnMatchupsError";
  }
}

function integer(value: unknown, field: string, minimum = 0) {
  if (!Number.isInteger(value) || Number(value) < minimum) {
    throw new EspnMatchupsError(
      "invalid_payload",
      `ESPN ${field} must be an integer of at least ${minimum}`,
    );
  }
  return Number(value);
}

function score(value: unknown, field: string) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    throw new EspnMatchupsError(
      "invalid_payload",
      `ESPN ${field} must be a nonnegative number`,
    );
  }
  return Math.round(value * 100) / 100;
}

function sourceUpdatedAt(payload: EspnLeaguePayload) {
  const value = Number(payload.status?.standingsUpdateDate);
  return Number.isFinite(value) && value > 0 ? new Date(value).toISOString() : null;
}

export function normalizeEspnMatchups({
  payload,
  expectedLeagueId,
  expectedSeason,
  mappings,
}: {
  payload: EspnLeaguePayload;
  expectedLeagueId: number;
  expectedSeason: number;
  mappings: EspnTeamMapping[];
}): NormalizedEspnMatchup[] {
  if (Number(payload.id) !== expectedLeagueId) {
    throw new EspnMatchupsError(
      "league_mismatch",
      "ESPN response league does not match the configured league",
    );
  }
  if (Number(payload.seasonId) !== expectedSeason) {
    throw new EspnMatchupsError(
      "season_mismatch",
      "ESPN response season does not match the requested season",
    );
  }
  if (!Array.isArray(payload.schedule)) {
    throw new EspnMatchupsError(
      "invalid_payload",
      "ESPN response does not contain a matchup schedule",
    );
  }

  const regularSeasonWeeks = integer(
    payload.settings?.scheduleSettings?.matchupPeriodCount,
    "regular-season matchup count",
    1,
  );
  const latestScoringPeriod = integer(
    payload.status?.latestScoringPeriod ?? 0,
    "latest scoring period",
  );
  const mappingByEspnId = new Map(
    mappings.map((mapping) => [mapping.espnTeamId, mapping.seasonTeamId]),
  );
  if (mappingByEspnId.size !== mappings.length) {
    throw new EspnMatchupsError(
      "team_mapping_incomplete",
      "ESPN team mappings must use unique source identifiers",
    );
  }

  const seenMatchups = new Set<number>();
  const normalized: NormalizedEspnMatchup[] = [];
  const updatedAt = sourceUpdatedAt(payload);

  for (const item of payload.schedule as EspnScheduleItem[]) {
    const matchupId = integer(item.id, "matchup ID", 1);
    const week = integer(item.matchupPeriodId, "matchup period", 1);
    if (week > 30) {
      throw new EspnMatchupsError(
        "invalid_payload",
        "ESPN matchup period exceeds the supported season range",
      );
    }
    if (seenMatchups.has(matchupId)) {
      throw new EspnMatchupsError(
        "invalid_payload",
        "ESPN matchup identifiers must be unique",
      );
    }
    seenMatchups.add(matchupId);

    if (week > latestScoringPeriod || item.winner === "UNDECIDED") continue;
    if (!["HOME", "AWAY", "TIE"].includes(String(item.winner))) {
      throw new EspnMatchupsError(
        "invalid_payload",
        "ESPN completed matchup has an invalid winner",
      );
    }
    if (!item.home || !item.away) {
      throw new EspnMatchupsError(
        "invalid_payload",
        "ESPN completed matchup must contain both teams",
      );
    }

    const homeEspnId = integer(item.home.teamId, "home team ID", 1);
    const awayEspnId = integer(item.away.teamId, "away team ID", 1);
    if (homeEspnId === awayEspnId) {
      throw new EspnMatchupsError(
        "invalid_payload",
        "ESPN matchup teams must be distinct",
      );
    }
    const homeSeasonTeamId = mappingByEspnId.get(homeEspnId);
    const awaySeasonTeamId = mappingByEspnId.get(awayEspnId);
    if (!homeSeasonTeamId || !awaySeasonTeamId) {
      throw new EspnMatchupsError(
        "team_mapping_incomplete",
        "Every completed ESPN matchup team must have a season mapping",
      );
    }

    const winner = String(item.winner);
    const matchupSourceKey =
      `espn:${expectedLeagueId}:${expectedSeason}:matchup:${matchupId}`;
    const homeResult = winner === "TIE" ? "tie" : winner === "HOME" ? "win" : "loss";
    const awayResult = winner === "TIE" ? "tie" : winner === "AWAY" ? "win" : "loss";

    normalized.push({
      espn_matchup_id: matchupId,
      week,
      phase: week <= regularSeasonWeeks ? "regular_season" : "postseason",
      source_key: matchupSourceKey,
      source_updated_at: updatedAt,
      results: [
        {
          season_team_id: homeSeasonTeamId,
          opponent_season_team_id: awaySeasonTeamId,
          espn_team_id: homeEspnId,
          score: score(item.home.totalPoints, "home score"),
          result: homeResult,
          source_key: `${matchupSourceKey}:team:${homeEspnId}`,
        },
        {
          season_team_id: awaySeasonTeamId,
          opponent_season_team_id: homeSeasonTeamId,
          espn_team_id: awayEspnId,
          score: score(item.away.totalPoints, "away score"),
          result: awayResult,
          source_key: `${matchupSourceKey}:team:${awayEspnId}`,
        },
      ],
    });
  }

  return normalized.sort(
    (left, right) => left.week - right.week || left.espn_matchup_id - right.espn_matchup_id,
  );
}
