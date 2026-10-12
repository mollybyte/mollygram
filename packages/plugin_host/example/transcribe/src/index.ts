// Расшифровка голосовых и кружков. Распознаёт речь приложение на
// устройстве, плагин решает, когда это делать, и рисует результат.

const cacheKey = (m: Mg.Message) => `t:${m.chatId}:${m.id}`;

async function transcribe(message: Mg.Message): Promise<Mg.UiNode[]> {
  if (!message.media) return [];
  const language = mg.settings.get<string>("language");
  const result = await mg.media.transcribe(message.media, {
    language: language === "auto" ? undefined : language,
  });
  await mg.storage.set(cacheKey(message), result.text);
  return [{ type: "text", text: result.text, style: "secondary" }];
}

async function render({ message }: Mg.RenderPayload): Promise<Mg.UiNode[]> {
  const cached = await mg.storage.get<string>(cacheKey(message));
  if (cached != null) return [{ type: "text", text: cached, style: "secondary" }];
  if (mg.settings.get<boolean>("auto")) return transcribe(message);
  return [{ type: "button", label: "Расшифровать", action: "transcribe" }];
}

mg.on("message.render.voice", render);
mg.on("message.render.round", render);

mg.on("ui.action", async ({ action, message }) => {
  if (action !== "transcribe" || !message) return;
  try {
    return await transcribe(message);
  } catch (e) {
    mg.log("не удалось расшифровать", String(e));
    return [{ type: "text", text: "Не удалось расшифровать", style: "secondary" }];
  }
});
