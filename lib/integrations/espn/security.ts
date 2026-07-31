import { createHash, timingSafeEqual } from "node:crypto";

export type EspnSyncRequest = {
  seasonId: string;
  idempotencyKey?: string;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const idempotencyKeyPattern = /^[A-Za-z0-9._:-]{1,200}$/;

function digest(value: string) {
  return createHash("sha256").update(value).digest();
}

export function secretsMatch(candidate: string | null, expected?: string) {
  if (!candidate || !expected) return false;
  return timingSafeEqual(digest(candidate), digest(expected));
}

export function bearerToken(authorization: string | null) {
  const match = authorization?.match(/^Bearer ([^\s]+)$/i);
  return match?.[1] ?? null;
}

export function parseEspnSyncRequest(
  body: unknown,
  idempotencyKeyHeader: string | null,
): EspnSyncRequest | null {
  if (!body || typeof body !== "object" || Array.isArray(body)) return null;
  const seasonId = (body as Record<string, unknown>).season_id;
  if (typeof seasonId !== "string" || !uuidPattern.test(seasonId)) return null;
  if (
    idempotencyKeyHeader !== null &&
    !idempotencyKeyPattern.test(idempotencyKeyHeader)
  ) {
    return null;
  }

  return {
    seasonId,
    ...(idempotencyKeyHeader ? { idempotencyKey: idempotencyKeyHeader } : {}),
  };
}
