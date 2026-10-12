// Mollygram plugin SDK types, version 1.0.
// A plugin runs in quickjs-ng without DOM, Node, fetch or timers.
// Everything that reaches the outside goes through the global `mg` object and
// is checked against the permissions in manifest.yaml. Spec: docs/plugins.md.

declare namespace Mg {
  type ChatId = number;
  type MessageId = number;

  interface MediaRef {
    kind: "voice" | "round" | "photo" | "video" | "document";
    /** Opaque file identifier, usable only in mg.media calls. */
    fileId: string;
    duration?: number;
  }

  interface Message {
    chatId: ChatId;
    id: MessageId;
    senderId: number;
    date: number;
    text?: string;
    media?: MediaRef;
    outgoing: boolean;
  }

  interface Draft {
    chatId: ChatId;
    text: string;
    replyTo?: MessageId;
  }

  interface Notification {
    chatId: ChatId;
    messageId: MessageId;
    title: string;
    body: string;
  }

  // --- Declarative UI ---

  type CodeToken = "plain" | "keyword" | "string" | "number" | "comment" | "function" | "type" | "punctuation";

  type UiNode =
    | { type: "text"; text: string; style?: "body" | "secondary" | "mono" }
    | { type: "button"; label: string; action: string; payload?: unknown }
    | { type: "toggle"; label: string; action: string; value: boolean }
    | { type: "progress"; label?: string }
    | { type: "row" | "column"; children: UiNode[] }
    | { type: "code"; language?: string; spans: { text: string; token?: CodeToken }[] };

  // --- Events ---

  type Awaitable<T> = T | Promise<T>;
  type InterceptResult<T> = void | { cancel: true } | { modify: T };

  interface MessagePayload { message: Message }
  interface RenderPayload { message: Message }
  interface CodePayload { message: Message; language?: string; code: string }
  interface ActionPayload { action: string; payload?: unknown; message?: Message }

  interface Events {
    "app.ready": [void, void];
    "chat.opened": [{ chatId: ChatId }, void];
    "message.incoming": [MessagePayload, void];
    "message.edited": [MessagePayload & { oldText?: string }, void];
    "message.deleted": [{ chatId: ChatId; messageIds: MessageId[] }, void];
    "message.sending": [Draft, InterceptResult<Draft>];
    "message.render.code": [CodePayload, UiNode[] | void];
    "message.render.voice": [RenderPayload, UiNode[] | void];
    "message.render.round": [RenderPayload, UiNode[] | void];
    "ui.action": [ActionPayload, UiNode[] | void];
    "notification.incoming": [Notification, InterceptResult<Notification> | { defer: number }];
    "settings.changed": [{ key: string; value: unknown }, void];
  }

  interface FetchInit {
    method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
    headers?: Record<string, string>;
    /** A string is sent as is, an object as JSON. */
    body?: string | object;
  }

  interface FetchResponse {
    status: number;
    headers: Record<string, string>;
    text: string;
  }

  /** An error from the host; `code` is, for example, "permission_denied". */
  interface HostError extends Error { code: string }
}

declare const mg: {
  /** Subscribes to an event. Only during load; the event must be in the manifest's `hooks`. */
  on<E extends keyof Mg.Events>(
    event: E,
    handler: (payload: Mg.Events[E][0]) => Mg.Awaitable<Mg.Events[E][1]>,
  ): void;

  /** Registers a handler for a command from the manifest's `commands`. */
  command(name: `/${string}`, handler: (args: unknown) => Mg.Awaitable<unknown>): void;

  readonly settings: {
    /** Returns the value of a setting from the manifest's `settings`. */
    get<T = unknown>(key: string): T;
  };

  /** The plugin's private storage. Requires `storage`. */
  readonly storage: {
    get<T = unknown>(key: string): Promise<T | null>;
    set(key: string, value: unknown): Promise<void>;
    delete(key: string): Promise<void>;
  };

  /** Requires `messages.read`. */
  readonly messages: {
    get(chatId: Mg.ChatId, messageId: Mg.MessageId): Promise<Mg.Message | null>;
    history(chatId: Mg.ChatId, options?: { limit?: number; before?: Mg.MessageId }): Promise<Mg.Message[]>;
  };

  /** Requires `composer.write`. */
  readonly composer: {
    insert(text: string): Promise<void>;
  };

  /** Requires `media.read` for the given kind. */
  readonly media: {
    /** On-device speech recognition provided by the app. */
    transcribe(media: Mg.MediaRef, options?: { language?: string }): Promise<{ text: string; language: string }>;
  };

  /** https only, and only hosts from `net`. No cookies and no redirects to other hosts. */
  readonly net: {
    fetch(url: string, init?: Mg.FetchInit): Promise<Mg.FetchResponse>;
  };

  readonly ui: {
    toast(text: string): Promise<void>;
  };

  log(...args: unknown[]): void;
};

declare const console: {
  log(...args: unknown[]): void;
  info(...args: unknown[]): void;
  warn(...args: unknown[]): void;
  error(...args: unknown[]): void;
};
