"use strict";
// Расшифровка голосовых и кружков. Распознаёт речь приложение на
// устройстве, плагин решает, когда это делать, и рисует результат.
const cacheKey = (m) => `t:${m.chatId}:${m.id}`;
async function transcribe(message) {
    if (!message.media)
        return [];
    const language = mg.settings.get("language");
    const result = await mg.media.transcribe(message.media, {
        language: language === "auto" ? undefined : language,
    });
    await mg.storage.set(cacheKey(message), result.text);
    return [{ type: "text", text: result.text, style: "secondary" }];
}
async function render({ message }) {
    const cached = await mg.storage.get(cacheKey(message));
    if (cached != null)
        return [{ type: "text", text: cached, style: "secondary" }];
    if (mg.settings.get("auto"))
        return transcribe(message);
    return [{ type: "button", label: "Расшифровать", action: "transcribe" }];
}
mg.on("message.render.voice", render);
mg.on("message.render.round", render);
mg.on("ui.action", async ({ action, message }) => {
    if (action !== "transcribe" || !message)
        return;
    try {
        return await transcribe(message);
    }
    catch (e) {
        mg.log("не удалось расшифровать", String(e));
        return [{ type: "text", text: "Не удалось расшифровать", style: "secondary" }];
    }
});
