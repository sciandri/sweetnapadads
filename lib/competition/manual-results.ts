const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const REQUEST_KEY_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$/;

export type ManualMatchupInput = {
  home_season_team_id: string;
  away_season_team_id: string;
  home_score: number;
  away_score: number;
};

function validScore(value: unknown): value is number {
  return typeof value === "number"
    && Number.isFinite(value)
    && value >= 0
    && value <= 999_999.99
    && Math.round(value * 100) / 100 === value;
}

function parseMatchup(value: unknown): ManualMatchupInput | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const row = value as Record<string, unknown>;
  if (
    typeof row.home_season_team_id !== "string"
    || !UUID_PATTERN.test(row.home_season_team_id)
    || typeof row.away_season_team_id !== "string"
    || !UUID_PATTERN.test(row.away_season_team_id)
    || row.home_season_team_id === row.away_season_team_id
    || !validScore(row.home_score)
    || !validScore(row.away_score)
  ) return null;
  return {
    home_season_team_id: row.home_season_team_id,
    away_season_team_id: row.away_season_team_id,
    home_score: row.home_score,
    away_score: row.away_score,
  };
}

export function parseManualResultsRequest(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const body = value as Record<string, unknown>;
  if (
    typeof body.season_id !== "string"
    || !UUID_PATTERN.test(body.season_id)
    || !Number.isInteger(body.week)
    || Number(body.week) < 1
    || Number(body.week) > 30
    || typeof body.reason !== "string"
    || body.reason.trim() !== body.reason
    || body.reason.length < 10
    || body.reason.length > 500
    || !Array.isArray(body.matchups)
    || body.matchups.length < 1
    || body.matchups.length > 50
  ) return null;

  const parsed = body.matchups.map(parseMatchup);
  if (parsed.some((row) => row === null)) return null;
  const matchups = parsed as ManualMatchupInput[];
  const teamIds = matchups.flatMap((row) => [
    row.home_season_team_id,
    row.away_season_team_id,
  ]);
  if (new Set(teamIds).size !== teamIds.length) return null;
  return {
    seasonId: body.season_id,
    week: Number(body.week),
    reason: body.reason,
    matchups,
  };
}
