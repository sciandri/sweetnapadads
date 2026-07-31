import { createHash } from "node:crypto";

import { normalizeEspnMatchups } from "@/lib/integrations/espn/matchups";
import type {
  EspnLeaguePayload,
  EspnTeam,
  EspnTeamMapping,
  NormalizedEspnStanding,
} from "@/lib/integrations/espn/types";

export class EspnStandingsError extends Error {
  constructor(
    readonly code:
      | "invalid_payload"
      | "league_mismatch"
      | "season_mismatch"
      | "standings_unavailable"
      | "team_mapping_incomplete",
    message: string,
  ) {
    super(message);
    this.name = "EspnStandingsError";
  }
}

function requiredInteger(value: unknown, field: string) {
  if (!Number.isInteger(value) || Number(value) < 0) {
    throw new EspnStandingsError(
      "invalid_payload",
      `ESPN ${field} must be a nonnegative integer`,
    );
  }
  return Number(value);
}

function requiredNumber(value: unknown, field: string) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    throw new EspnStandingsError(
      "invalid_payload",
      `ESPN ${field} must be a nonnegative number`,
    );
  }
  return Math.round(value * 100) / 100;
}

function positiveRank(value: unknown) {
  return Number.isInteger(value) && Number(value) > 0 ? Number(value) : null;
}

function officialRank(team: EspnTeam, useFinalRank: boolean) {
  return positiveRank(
    useFinalRank ? team.rankCalculatedFinal : team.playoffSeed,
  );
}

export function normalizeEspnStandings({
  payload,
  expectedLeagueId,
  expectedSeason,
  mappings,
}: {
  payload: EspnLeaguePayload;
  expectedLeagueId: number;
  expectedSeason: number;
  mappings: EspnTeamMapping[];
}): NormalizedEspnStanding[] {
  if (Number(payload.id) !== expectedLeagueId) {
    throw new EspnStandingsError(
      "league_mismatch",
      "ESPN response league does not match the configured league",
    );
  }
  if (Number(payload.seasonId) !== expectedSeason) {
    throw new EspnStandingsError(
      "season_mismatch",
      "ESPN response season does not match the requested season",
    );
  }
  if (!Array.isArray(payload.teams) || payload.teams.length === 0) {
    throw new EspnStandingsError(
      "invalid_payload",
      "ESPN response does not contain teams",
    );
  }

  const teams = payload.teams as EspnTeam[];
  const finalScoringPeriod = positiveRank(payload.status?.finalScoringPeriod);
  const latestScoringPeriod = requiredInteger(
    payload.status?.latestScoringPeriod ?? 0,
    "latest scoring period",
  );
  const useFinalRank =
    finalScoringPeriod !== null && latestScoringPeriod >= finalScoringPeriod;
  const ranks = teams.map((team) => officialRank(team, useFinalRank));

  if (ranks.some((rank) => rank === null)) {
    throw new EspnStandingsError(
      "standings_unavailable",
      "ESPN has not published an official standings order for this season",
    );
  }
  const sortedRanks = [...(ranks as number[])].sort((left, right) => left - right);
  if (sortedRanks.some((rank, index) => rank !== index + 1)) {
    throw new EspnStandingsError(
      "invalid_payload",
      "ESPN official standings ranks are not unique and contiguous",
    );
  }

  const mappingByEspnId = new Map(
    mappings.map((mapping) => [mapping.espnTeamId, mapping.seasonTeamId]),
  );
  if (mappingByEspnId.size !== mappings.length || mappings.length !== teams.length) {
    throw new EspnStandingsError(
      "team_mapping_incomplete",
      "ESPN standings must exactly match the configured season-team mappings",
    );
  }

  const normalized = teams.map((team, index) => {
    const espnTeamId = requiredInteger(team.id, "team ID");
    if (espnTeamId === 0) {
      throw new EspnStandingsError("invalid_payload", "ESPN team ID must be positive");
    }
    const seasonTeamId = mappingByEspnId.get(espnTeamId);
    if (!seasonTeamId) {
      throw new EspnStandingsError(
        "team_mapping_incomplete",
        `ESPN team ${espnTeamId} does not have a season-team mapping`,
      );
    }
    const record = team.record?.overall;
    if (!record) {
      throw new EspnStandingsError(
        "invalid_payload",
        `ESPN team ${espnTeamId} does not have an overall record`,
      );
    }
    const wins = requiredInteger(record.wins, "wins");
    const losses = requiredInteger(record.losses, "losses");
    const ties = requiredInteger(record.ties, "ties");
    const streakLength = requiredInteger(record.streakLength, "streak length");
    const streakType =
      typeof record.streakType === "string" ? record.streakType : "NONE";
    const streak =
      streakLength > 0 && ["WIN", "LOSS", "TIE"].includes(streakType)
        ? `${streakType[0]}${streakLength}`
        : null;
    const rank = (ranks as number[])[index];
    const playoffSeed = positiveRank(team.playoffSeed);

    return {
      season_team_id: seasonTeamId,
      espn_team_id: espnTeamId,
      official_rank: rank,
      playoff_seed: playoffSeed,
      wins,
      losses,
      ties,
      points_for: requiredNumber(record.pointsFor, "points for"),
      points_against: requiredNumber(record.pointsAgainst, "points against"),
      streak,
      record_summary: ties ? `${wins}-${losses}-${ties}` : `${wins}-${losses}`,
      source_record: {
        id: espnTeamId,
        playoffSeed: team.playoffSeed ?? null,
        rankCalculatedFinal: team.rankCalculatedFinal ?? null,
        points: team.points ?? null,
        record: { overall: record },
      },
    } satisfies NormalizedEspnStanding;
  });

  return normalized.sort(
    (left, right) => left.official_rank - right.official_rank,
  );
}

export function sha256(value: string) {
  return createHash("sha256").update(value).digest("hex");
}

export function buildEspnStandingsIngestion({
  leagueId,
  seasonId,
  seasonYear,
  espnLeagueId,
  response,
  mappings,
  idempotencyKey,
}: {
  leagueId: string;
  seasonId: string;
  seasonYear: number;
  espnLeagueId: number;
  response: {
    endpointPath: string;
    fetchedAt: string;
    httpStatus: number;
    payload: EspnLeaguePayload;
    rawText: string;
  };
  mappings: EspnTeamMapping[];
  idempotencyKey?: string;
}) {
  const payloadHash = sha256(response.rawText);
  const entries = normalizeEspnStandings({
    payload: response.payload,
    expectedLeagueId: espnLeagueId,
    expectedSeason: seasonYear,
    mappings,
  });
  const matchups = normalizeEspnMatchups({
    payload: response.payload,
    expectedLeagueId: espnLeagueId,
    expectedSeason: seasonYear,
    mappings,
  });
  const scoringPeriodValue = Number(response.payload.scoringPeriodId);
  const scoringPeriod =
    Number.isInteger(scoringPeriodValue) && scoringPeriodValue > 0
      ? scoringPeriodValue
      : null;
  const standingsUpdate = Number(response.payload.status?.standingsUpdateDate);
  const capturedAt =
    Number.isFinite(standingsUpdate) && standingsUpdate > 0
      ? new Date(standingsUpdate).toISOString()
      : response.fetchedAt;
  const sourceRevision = `sha256:${payloadHash}`;
  const sourceKey =
    `espn:${espnLeagueId}:${seasonYear}:standings:` +
    `${scoringPeriod ?? "preseason"}:${payloadHash}`;

  return {
    target_league_id: leagueId,
    target_season_id: seasonId,
    target_scoring_period: scoringPeriod,
    target_source_revision: sourceRevision,
    target_idempotency_key: idempotencyKey ?? sourceKey,
    target_endpoint_path: response.endpointPath,
    target_http_status: response.httpStatus,
    target_raw_payload: response.payload,
    target_payload_sha256: payloadHash,
    target_fetched_at: response.fetchedAt,
    target_espn_league_id: espnLeagueId,
    target_source_key: sourceKey,
    target_captured_at: capturedAt,
    target_entries: entries,
    target_matchups: matchups,
  };
}
