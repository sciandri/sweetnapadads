import type {
  MessageContextSelection,
  MessageLength,
  MessageTone,
} from "@/lib/messages/context";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TONES = new Set<MessageTone>(["concise", "friendly", "energetic"]);
const LENGTHS = new Set<MessageLength>(["short", "medium", "long"]);

export type MessageDraftRequest = {
  seasonId: string;
  week: number;
  selection: MessageContextSelection;
  notes: string;
  tone: MessageTone;
  length: MessageLength;
};

export function parseMessageDraftRequest(
  value: unknown,
): MessageDraftRequest | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const body = value as Record<string, unknown>;
  const selection = body.selection;

  if (
    typeof body.season_id !== "string" ||
    !UUID_PATTERN.test(body.season_id) ||
    typeof body.week !== "number" ||
    !Number.isInteger(body.week) ||
    body.week < 1 ||
    body.week > 30 ||
    !selection ||
    typeof selection !== "object" ||
    Array.isArray(selection) ||
    typeof (selection as Record<string, unknown>).includeStandings !== "boolean" ||
    typeof (selection as Record<string, unknown>).includeResults !== "boolean" ||
    typeof (selection as Record<string, unknown>).includeAwards !== "boolean" ||
    typeof body.notes !== "string" ||
    body.notes.length > 1_200 ||
    typeof body.tone !== "string" ||
    !TONES.has(body.tone as MessageTone) ||
    typeof body.length !== "string" ||
    !LENGTHS.has(body.length as MessageLength)
  ) {
    return null;
  }

  return {
    seasonId: body.season_id,
    week: body.week,
    selection: selection as MessageContextSelection,
    notes: body.notes,
    tone: body.tone as MessageTone,
    length: body.length as MessageLength,
  };
}
