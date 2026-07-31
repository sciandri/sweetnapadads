import type {
  CommissionerMessageContext,
  MessageContextSelection,
  MessageLength,
  MessageTone,
} from "@/lib/messages/context";

export const MESSAGE_DRAFT_SYSTEM_INSTRUCTIONS = `You draft messages for the Sweet Looking Napa Dads league's existing group-text thread.

Use only facts in the supplied context and commissioner notes. ESPN's official standings order is authoritative: never calculate, infer, or reorder it. Never invent scores, records, awards, dates, people, or financial information. If requested information is absent, omit it instead of guessing.

Return editable message copy only. Do not address individual recipients, claim the message was sent, or include delivery instructions. Keep the selected tone while making the message natural for a long-running private league thread.`;

type BuildMessagePromptInput = {
  context: CommissionerMessageContext;
  selection: MessageContextSelection;
  notes: string;
  tone: MessageTone;
  length: MessageLength;
};

const lengthGuidance: Record<MessageLength, string> = {
  short: "Aim for 1-3 compact sentences.",
  medium: "Aim for one concise paragraph or 4-6 short lines.",
  long: "Aim for a readable recap of no more than 3 short paragraphs.",
};

export function buildMessageDraftPrompt({
  context,
  selection,
  notes,
  tone,
  length,
}: BuildMessagePromptInput) {
  const selectedFacts = {
    league: context.league,
    season: context.season,
    selected_week: context.selected_week,
    standings: selection.includeStandings ? context.standings : undefined,
    results: selection.includeResults ? context.results : undefined,
    awards: selection.includeAwards ? context.awards : undefined,
    financial_context_included: false,
  };

  return [
    `Tone: ${tone}.`,
    lengthGuidance[length],
    "Create three distinct draft options.",
    `Commissioner notes:\n${notes.trim() || "No additional notes."}`,
    `Verified league context:\n${JSON.stringify(selectedFacts, null, 2)}`,
  ].join("\n\n");
}
