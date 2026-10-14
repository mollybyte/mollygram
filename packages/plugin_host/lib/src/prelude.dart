/// JS that runs in every VM before the plugin code.
///
/// It hides `__mg_host` and creates the frozen `mg` object and the event
/// dispatcher. Types for plugin authors live in packages/plugin_sdk.
const prelude = r'''
"use strict";
(() => {
  const host = globalThis.__mg_host;
  delete globalThis.__mg_host;

  const pending = new Map();
  const handlers = new Map();
  const commands = new Map();
  let ready = false;

  // Calls the host. Reply: {ok}, {error}, or {pending: id} for async calls.
  function request(method, args) {
    const raw = host(method, JSON.stringify(args === undefined ? null : args));
    const res = raw == null ? { ok: null } : JSON.parse(raw);
    if (res.error) {
      const e = new Error(res.error.message || res.error.code);
      e.code = res.error.code;
      return Promise.reject(e);
    }
    if (res.pending !== undefined) {
      return new Promise((resolve, reject) => pending.set(res.pending, { resolve, reject }));
    }
    return Promise.resolve(res.ok);
  }

  function requestSync(method, args) {
    const raw = host(method, JSON.stringify(args === undefined ? null : args));
    const res = raw == null ? { ok: null } : JSON.parse(raw);
    if (res.error) {
      const e = new Error(res.error.message || res.error.code);
      e.code = res.error.code;
      throw e;
    }
    return res.ok;
  }

  const fmt = (args) => args.map((a) => typeof a === "string" ? a : JSON.stringify(a)).join(" ");
  const log = (level) => (...args) => host("log", JSON.stringify({ level, text: fmt(args) }));

  const mg = {
    on(event, fn) {
      if (ready) throw new Error("mg.on can only be called during load");
      if (typeof fn !== "function") throw new TypeError("mg.on(event, fn)");
      requestSync("hooks.check", { event });
      if (!handlers.has(event)) handlers.set(event, []);
      handlers.get(event).push(fn);
    },
    command(name, fn) {
      if (ready) throw new Error("mg.command can only be called during load");
      requestSync("commands.check", { name });
      commands.set(name, fn);
    },
    settings: {
      get: (key) => requestSync("settings.get", { key }),
    },
    storage: {
      get: (key) => request("storage.get", { key }),
      set: (key, value) => request("storage.set", { key, value }),
      delete: (key) => request("storage.delete", { key }),
    },
    messages: {
      get: (chatId, messageId) => request("messages.get", { chatId, messageId }),
      history: (chatId, options) => request("messages.history", { chatId, ...options }),
      translate: (chatId, messageId, options) => request("messages.translate", { chatId, messageId, ...options }),
    },
    text: {
      detectLanguage: (text) => request("text.detectLanguage", { text }),
    },
    app: {
      locale: () => requestSync("app.locale"),
    },
    composer: {
      insert: (text) => request("composer.insert", { text }),
    },
    media: {
      transcribe: (media, options) => request("media.transcribe", { media, ...options }),
    },
    net: {
      fetch: (url, init) => request("net.fetch", { url, ...init }),
    },
    ui: {
      toast: (text) => request("ui.toast", { text }),
    },
    log: log("info"),
  };
  for (const v of Object.values(mg)) if (typeof v === "object") Object.freeze(v);
  Object.defineProperty(globalThis, "mg", { value: Object.freeze(mg), enumerable: true });
  globalThis.console = Object.freeze({ log: log("info"), info: log("info"), warn: log("warn"), error: log("error") });

  let nextRun = 1;
  function finish(value) {
    if (value === null || typeof value !== "object" || typeof value.then !== "function") {
      return { done: true, value: value === undefined ? null : value };
    }
    const id = nextRun++;
    value.then(
      (v) => host("run.done", JSON.stringify({ id, value: v === undefined ? null : v })),
      (e) => host("run.done", JSON.stringify({ id, error: e instanceof Error ? e + "\n" + e.stack : String(e) })),
    );
    return { done: false, id };
  }

  // Handlers of one event run in order. For interception, {modify} passes
  // the modified data to the next handler and {cancel} stops the chain.
  async function runHandlers(list, payload) {
    const results = [];
    for (const fn of list) {
      const r = await fn(payload);
      if (r && r.cancel === true) return { cancel: true };
      if (r && r.modify !== undefined) payload = r.modify;
      if (r !== undefined) results.push(r);
    }
    return { payload, results };
  }

  function dispatch(msg) {
    switch (msg.kind) {
      case "ready":
        ready = true;
        return { done: true, value: { events: [...handlers.keys()], commands: [...commands.keys()] } };
      case "event": {
        const list = handlers.get(msg.event);
        if (!list) return { done: true, value: { payload: msg.payload, results: [] } };
        return finish(runHandlers(list, msg.payload));
      }
      case "command": {
        const fn = commands.get(msg.name);
        if (!fn) throw new Error("no command " + msg.name);
        return finish(fn(msg.args));
      }
      case "settle": {
        const p = pending.get(msg.id);
        if (!p) return { done: true, value: null };
        pending.delete(msg.id);
        if (msg.error) {
          const e = new Error(msg.error.message || msg.error.code);
          e.code = msg.error.code;
          p.reject(e);
        } else {
          p.resolve(msg.value);
        }
        return { done: true, value: null };
      }
    }
    throw new Error("unknown message " + msg.kind);
  }
  Object.defineProperty(globalThis, "__mg_dispatch", { value: dispatch });
})();
''';
