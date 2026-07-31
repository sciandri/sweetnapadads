export type EspnMappingUpdate = {
  seasonId: string;
  mappings: Array<{
    season_team_id: string;
    espn_team_id: number;
  }>;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parseEspnMappingUpdate(body: unknown): EspnMappingUpdate | null {
  if (!body || typeof body !== "object" || Array.isArray(body)) return null;
  const value = body as Record<string, unknown>;
  if (typeof value.season_id !== "string" || !uuidPattern.test(value.season_id)) {
    return null;
  }
  if (!Array.isArray(value.mappings) || value.mappings.length === 0) return null;

  const mappings = value.mappings.map((mapping) => {
    if (!mapping || typeof mapping !== "object" || Array.isArray(mapping)) {
      return null;
    }
    const row = mapping as Record<string, unknown>;
    if (
      typeof row.season_team_id !== "string" ||
      !uuidPattern.test(row.season_team_id) ||
      !Number.isInteger(row.espn_team_id) ||
      Number(row.espn_team_id) <= 0
    ) {
      return null;
    }
    return {
      season_team_id: row.season_team_id,
      espn_team_id: Number(row.espn_team_id),
    };
  });

  if (mappings.some((mapping) => mapping === null)) return null;
  const validMappings = mappings as EspnMappingUpdate["mappings"];
  if (
    new Set(validMappings.map((mapping) => mapping.season_team_id)).size !==
      validMappings.length ||
    new Set(validMappings.map((mapping) => mapping.espn_team_id)).size !==
      validMappings.length
  ) {
    return null;
  }

  return { seasonId: value.season_id, mappings: validMappings };
}
