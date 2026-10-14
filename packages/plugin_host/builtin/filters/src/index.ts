// Collapses or hides advertising and messages with the user's keywords.
// Everything runs on the device: the plugin has no network and no storage.

// Markers channels put on paid posts. "erid" is the token Russian law
// requires on every ad, so it is the most reliable one.
const adMarkers = [
  /(?:^|[\s(])erid[:=\s]\s*[0-9A-Za-z]{6,}/i,
  /(?:^|\s)#(?:реклама|ad|ads|advert|advertising|sponsored|promo|промо|партнер|партнёр)(?![\p{L}\p{N}_])/iu,
  /^\s*(?:реклама|на правах рекламы|advertisement|sponsored|ad)\s*[.:|]?\s*$/imu,
];

const strings = {
  en: { ad: "Advertising", keyword: (k: string) => `Keyword: ${k}` },
  ru: { ad: "Реклама", keyword: (k: string) => `Ключевое слово: ${k}` },
};

const t = () => (mg.app.locale() === "ru" ? strings.ru : strings.en);

const escapeRegExp = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

let keywords: { word: string; re: RegExp }[] = [];

// Whole words only, so "ad" does not match "already", in any script.
function compile(raw: unknown) {
  keywords = String(raw ?? "")
    .split(/[,\n]/)
    .map((w) => w.trim())
    .filter((w) => w.length > 0)
    .slice(0, 200)
    .map((word) => ({
      word,
      re: new RegExp(`(?<![\\p{L}\\p{N}_])${escapeRegExp(word)}(?![\\p{L}\\p{N}_])`, "iu"),
    }));
}

compile(mg.settings.get("keywords"));

mg.on("settings.changed", ({ key, value }) => {
  if (key === "keywords") compile(value);
});

mg.on("message.filter", ({ message }): Mg.FilterResult => {
  const text = message.text;
  // The user's own messages are never filtered.
  if (!text || message.outgoing) return;
  const filter = mg.settings.get<"collapse" | "hide">("mode");
  if (mg.settings.get<boolean>("ads") && adMarkers.some((re) => re.test(text))) {
    return { filter, reason: t().ad };
  }
  const hit = keywords.find((k) => k.re.test(text));
  if (hit) return { filter, reason: t().keyword(hit.word) };
});
