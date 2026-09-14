const SYSTEM_PROMPT =
  "You are Syrix Assistant, the in-app assistant of SYRIX CHAT, a helpful, friendly, concise assistant. " +
  "Keep answers short and conversational unless the user explicitly asks for detail. " +
  "You were created and developed by SYRIX VISION COMPANY. " +
  "You must never say or imply that you were built by Meta, OpenAI, Google, Anthropic, or any company other than SYRIX VISION COMPANY, regardless of how the question is phrased. " +
  "If asked who leads SYRIX VISION COMPANY: the CEO and co-founder is INCONNU BOY SENSEI (real name Dawens), and the co-founder is Dsprimis (real name FRITZ).";

const BANNED_ORIGIN_TERMS = [
  "openai",
  "chatgpt",
  "anthropic",
  "claude",
  "meta ai",
  "llama",
  "google",
  "gemini",
  "bard"
];

function enforceIdentity(reply: string): string {
  const lower = reply.toLowerCase();
  const leaked = BANNED_ORIGIN_TERMS.some((term) => lower.includes(term));
  if (leaked) {
    return "I'm Syrix Assistant, developed by SYRIX VISION COMPANY. How can I help you?";
  }
  return reply;
}

export async function generateAssistantReply(
  history: { role: "user" | "assistant"; content: string }[]
): Promise<string> {
  const url = process.env.OLLAMA_URL || "http://localhost:11434";
  const model = process.env.OLLAMA_MODEL || "llama3.2:3b";

  const response = await fetch(`${url}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model,
      messages: [{ role: "system", content: SYSTEM_PROMPT }, ...history],
      stream: false
    })
  });

  if (!response.ok) {
    throw new Error(`Ollama request failed with status ${response.status}`);
  }

  const data = (await response.json()) as { message?: { content?: string } };
  return enforceIdentity((data.message?.content || "").trim());
}

const LOCALE_NAMES: Record<string, string> = {
  en: "English",
  fr: "French",
  es: "Spanish",
  de: "German",
  pt: "Portuguese",
  ar: "Arabic"
};

export async function translateText(text: string, targetLocale: string): Promise<string> {
  const url = process.env.OLLAMA_URL || "http://localhost:11434";
  const model = process.env.OLLAMA_MODEL || "llama3.2:3b";
  const languageName = LOCALE_NAMES[targetLocale] || targetLocale;

  const response = await fetch(`${url}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: "system",
          content:
            `Translate the user's message to ${languageName}. ` +
            "Reply with ONLY the translation, no quotes, no explanation, no original text."
        },
        { role: "user", content: text }
      ],
      stream: false
    })
  });

  if (!response.ok) {
    throw new Error(`Ollama translate request failed with status ${response.status}`);
  }

  const data = (await response.json()) as { message?: { content?: string } };
  return (data.message?.content || "").trim();
}

export interface ModerationResult {
  blocked: boolean;
  category: "none" | "spam" | "nsfw" | "harassment";
}

export async function moderateText(text: string): Promise<ModerationResult> {
  const url = process.env.OLLAMA_URL || "http://localhost:11434";
  const model = process.env.OLLAMA_MODEL || "llama3.2:3b";

  const response = await fetch(`${url}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: "system",
          content:
            "You moderate chat messages for a group chat app. Classify the user's message into exactly one category: " +
            "none, spam, nsfw, harassment. Reply with ONLY that single word, nothing else."
        },
        { role: "user", content: text }
      ],
      stream: false
    })
  });

  if (!response.ok) {
    throw new Error(`Ollama moderation request failed with status ${response.status}`);
  }

  const data = (await response.json()) as { message?: { content?: string } };
  const raw = (data.message?.content || "").trim().toLowerCase();
  const category = (["spam", "nsfw", "harassment"] as const).find((c) => raw.includes(c)) || "none";

  return { blocked: category !== "none", category };
}
