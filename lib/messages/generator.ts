import type { CommissionerMessageContext } from "@/lib/messages/context";
import type { MessageDraftRequest } from "@/lib/messages/input";
import {
  buildMessageDraftPrompt,
  MESSAGE_DRAFT_SYSTEM_INSTRUCTIONS,
} from "@/lib/messages/prompt";

const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const DEFAULT_MODEL = "gpt-5.6-terra";

const outputSchema = {
  type: "object",
  properties: {
    draft_1: { type: "string" },
    draft_2: { type: "string" },
    draft_3: { type: "string" },
  },
  required: ["draft_1", "draft_2", "draft_3"],
  additionalProperties: false,
} as const;

type OpenAIResponse = {
  status?: string;
  output_text?: string;
  output?: Array<{
    type?: string;
    content?: Array<{ type?: string; text?: string; refusal?: string }>;
  }>;
};

export class MessageGenerationError extends Error {
  constructor(public readonly code: "generation_failed" | "generation_refused") {
    super(code);
  }
}

function responseText(response: OpenAIResponse) {
  if (typeof response.output_text === "string") return response.output_text;
  return response.output
    ?.flatMap((item) => item.content ?? [])
    .find((content) => content.type === "output_text")?.text;
}

export async function generateMessageDrafts({
  apiKey,
  context,
  request,
}: {
  apiKey: string;
  context: CommissionerMessageContext;
  request: MessageDraftRequest;
}) {
  const response = await fetch(OPENAI_RESPONSES_URL, {
    method: "POST",
    headers: {
      authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: process.env.OPENAI_MODEL?.trim() || DEFAULT_MODEL,
      store: false,
      reasoning: { effort: "none" },
      max_output_tokens: 1_200,
      instructions: MESSAGE_DRAFT_SYSTEM_INSTRUCTIONS,
      input: buildMessageDraftPrompt({
        context,
        selection: request.selection,
        notes: request.notes,
        tone: request.tone,
        length: request.length,
      }),
      text: {
        format: {
          type: "json_schema",
          name: "commissioner_message_drafts",
          strict: true,
          schema: outputSchema,
        },
      },
    }),
    signal: AbortSignal.timeout(20_000),
  });

  if (!response.ok) throw new MessageGenerationError("generation_failed");
  const payload = (await response.json()) as OpenAIResponse;
  const refused = payload.output
    ?.flatMap((item) => item.content ?? [])
    .some((content) => content.type === "refusal");
  if (refused) throw new MessageGenerationError("generation_refused");
  if (payload.status !== "completed") {
    throw new MessageGenerationError("generation_failed");
  }

  const text = responseText(payload);
  if (!text) throw new MessageGenerationError("generation_failed");

  try {
    const parsed = JSON.parse(text) as Record<string, unknown>;
    const drafts = [parsed.draft_1, parsed.draft_2, parsed.draft_3];
    if (
      drafts.some(
        (draft) =>
          typeof draft !== "string" ||
          draft.trim().length === 0 ||
          draft.length > 3_000,
      )
    ) {
      throw new Error("invalid output");
    }
    return drafts as [string, string, string];
  } catch {
    throw new MessageGenerationError("generation_failed");
  }
}
