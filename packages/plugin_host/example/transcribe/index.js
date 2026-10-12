"use strict";
// Transcribes voice and round video messages. The app recognizes speech on
// the device; the plugin decides when to do it and renders the result.
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
    return [{ type: "button", label: "Transcribe", action: "transcribe" }];
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
        mg.log("transcription failed", String(e));
        return [{ type: "text", text: "Transcription failed", style: "secondary" }];
    }
});
