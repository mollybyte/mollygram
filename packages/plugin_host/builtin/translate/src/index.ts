// Translates messages in other languages with Telegram's own translation.
// The language is detected on the device, and a message is sent for
// translation only when the user taps "Translate" or turns on automatic
// translation.

const names: Record<string, { en: string; ru: string }> = {
  en: { en: "English", ru: "английского" },
  ru: { en: "Russian", ru: "русского" },
  uk: { en: "Ukrainian", ru: "украинского" },
  be: { en: "Belarusian", ru: "белорусского" },
  de: { en: "German", ru: "немецкого" },
  es: { en: "Spanish", ru: "испанского" },
  fr: { en: "French", ru: "французского" },
  it: { en: "Italian", ru: "итальянского" },
  pt: { en: "Portuguese", ru: "португальского" },
  pl: { en: "Polish", ru: "польского" },
  nl: { en: "Dutch", ru: "нидерландского" },
  tr: { en: "Turkish", ru: "турецкого" },
  ar: { en: "Arabic", ru: "арабского" },
  fa: { en: "Persian", ru: "персидского" },
  he: { en: "Hebrew", ru: "иврита" },
  hi: { en: "Hindi", ru: "хинди" },
  zh: { en: "Chinese", ru: "китайского" },
  ja: { en: "Japanese", ru: "японского" },
  ko: { en: "Korean", ru: "корейского" },
  kk: { en: "Kazakh", ru: "казахского" },
  uz: { en: "Uzbek", ru: "узбекского" },
};

const ru = () => mg.app.locale() === "ru";

const strings = {
  translate: (from: string) => {
    const n = names[from];
    if (ru()) return n ? `Перевести с ${n.ru}` : "Перевести";
    return n ? `Translate from ${n.en}` : "Translate";
  },
  translated: (from: string) => {
    const n = names[from];
    if (ru()) return n ? `Переведено с ${n.ru}` : "Переведено";
    return n ? `Translated from ${n.en}` : "Translated";
  },
  hide: () => (ru() ? "Скрыть перевод" : "Hide translation"),
  failed: () => (ru() ? "Не удалось перевести" : "Could not translate"),
};

// Detection is unreliable on very short texts such as "ok" or "lol".
const minLength = 12;
const minConfidence = 0.6;

const target = () => {
  const to = mg.settings.get<string>("to");
  return to === "app" ? mg.app.locale() : to;
};

const skipped = () =>
  String(mg.settings.get("skip") ?? "")
    .split(/[,\s]+/)
    .map((s) => s.trim().toLowerCase())
    .filter((s) => s.length > 0);

// A cheap hash, so an edited message does not show a stale translation.
function hash(s: string) {
  let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h * 33) ^ s.charCodeAt(i)) >>> 0;
  return h.toString(36);
}

const cacheKey = (m: Mg.Message, to: string) => `t:${to}:${m.chatId}:${m.id}:${hash(m.text ?? "")}`;

interface Cached {
  from: string;
  text: string;
}

function shown(c: Cached): Mg.UiNode[] {
  return [
    { type: "text", text: c.text },
    {
      type: "row",
      children: [
        { type: "text", text: strings.translated(c.from), style: "secondary" },
        { type: "button", label: strings.hide(), action: "hide", payload: { from: c.from } },
      ],
    },
  ];
}

const offer = (from: string): Mg.UiNode[] => [
  { type: "button", label: strings.translate(from), action: "translate", payload: { from } },
];

async function translate(message: Mg.Message, from: string): Promise<Mg.UiNode[]> {
  const to = target();
  try {
    const { text } = await mg.messages.translate(message.chatId, message.id, { to });
    const c = { from, text };
    try {
      await mg.storage.set(cacheKey(message, to), c);
    } catch (e) {
      // A full cache only costs a repeated request later.
      mg.log("cache write failed", String(e));
    }
    return shown(c);
  } catch (e) {
    mg.log("translation failed", String(e));
    return [{ type: "text", text: strings.failed(), style: "secondary" }];
  }
}

mg.on("message.render.text", async ({ message }) => {
  const text = message.text;
  if (!text || message.outgoing || text.trim().length < minLength) return [];
  const to = target();
  const cached = await mg.storage.get<Cached>(cacheKey(message, to));
  if (cached) return shown(cached);

  const detected = await mg.text.detectLanguage(text);
  if (!detected || detected.confidence < minConfidence) return [];
  const from = detected.language.toLowerCase();
  if (from === to || skipped().includes(from)) return [];

  if (mg.settings.get<boolean>("auto")) return translate(message, from);
  return offer(from);
});

mg.on("ui.action", async ({ action, payload, message }) => {
  if (!message) return;
  const from = String((payload as { from?: string } | undefined)?.from ?? "");
  if (action === "translate") return translate(message, from);
  if (action === "hide") {
    await mg.storage.delete(cacheKey(message, target()));
    return offer(from);
  }
});
