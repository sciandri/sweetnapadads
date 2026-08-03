const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const NOTIFICATION_KEY_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$/;

const KINDS = new Set(["announcement", "reminder", "result", "finance", "system"]);
const AUDIENCES = new Set(["all_members", "commissioners"]);

export function parseNotificationRequest(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const body = value as Record<string, unknown>;
  const seasonId = body.season_id === null ? null : body.season_id;
  if (
    typeof body.league_id !== "string"
    || !UUID_PATTERN.test(body.league_id)
    || (seasonId !== null && (typeof seasonId !== "string" || !UUID_PATTERN.test(seasonId)))
    || typeof body.kind !== "string"
    || !KINDS.has(body.kind)
    || typeof body.audience !== "string"
    || !AUDIENCES.has(body.audience)
    || typeof body.title !== "string"
    || body.title.trim() !== body.title
    || body.title.length < 1
    || body.title.length > 120
    || typeof body.body !== "string"
    || body.body.trim() !== body.body
    || body.body.length < 1
    || body.body.length > 2_000
  ) return null;
  return {
    leagueId: body.league_id,
    seasonId: seasonId as string | null,
    kind: body.kind as "announcement" | "reminder" | "result" | "finance" | "system",
    audience: body.audience as "all_members" | "commissioners",
    title: body.title,
    body: body.body,
  };
}
