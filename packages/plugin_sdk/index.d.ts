// Типы SDK плагинов Mollygram, версия 1.0.
// Плагин выполняется в quickjs-ng без DOM, Node, fetch и таймеров.
// Всё, что выходит наружу, идёт через глобальный объект `mg` и проверяется
// по правам из manifest.yaml. Спецификация: docs/plugins.md.

declare namespace Mg {
  type ChatId = number;
  type MessageId = number;

  interface MediaRef {
    kind: "voice" | "round" | "photo" | "video" | "document";
    /** Непрозрачный идентификатор файла, годится только для вызовов mg.media. */
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

  // --- Декларативный UI ---

  type CodeToken = "plain" | "keyword" | "string" | "number" | "comment" | "function" | "type" | "punctuation";

  type UiNode =
    | { type: "text"; text: string; style?: "body" | "secondary" | "mono" }
    | { type: "button"; label: string; action: string; payload?: unknown }
    | { type: "toggle"; label: string; action: string; value: boolean }
    | { type: "progress"; label?: string }
    | { type: "row" | "column"; children: UiNode[] }
    | { type: "code"; language?: string; spans: { text: string; token?: CodeToken }[] };

  // --- События ---

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
    /** Строка уходит как есть, объект как JSON. */
    body?: string | object;
  }

  interface FetchResponse {
    status: number;
    headers: Record<string, string>;
    text: string;
  }

  /** Ошибка из хоста; `code` например "permission_denied". */
  interface HostError extends Error { code: string }
}

declare const mg: {
  /** Подписка на событие. Только при загрузке; событие должно быть в `hooks` манифеста. */
  on<E extends keyof Mg.Events>(
    event: E,
    handler: (payload: Mg.Events[E][0]) => Mg.Awaitable<Mg.Events[E][1]>,
  ): void;

  /** Обработчик команды из `commands` манифеста. */
  command(name: `/${string}`, handler: (args: unknown) => Mg.Awaitable<unknown>): void;

  readonly settings: {
    /** Значение параметра из `settings` манифеста. */
    get<T = unknown>(key: string): T;
  };

  /** Личное хранилище плагина. Требует `storage`. */
  readonly storage: {
    get<T = unknown>(key: string): Promise<T | null>;
    set(key: string, value: unknown): Promise<void>;
    delete(key: string): Promise<void>;
  };

  /** Требует `messages.read`. */
  readonly messages: {
    get(chatId: Mg.ChatId, messageId: Mg.MessageId): Promise<Mg.Message | null>;
    history(chatId: Mg.ChatId, options?: { limit?: number; before?: Mg.MessageId }): Promise<Mg.Message[]>;
  };

  /** Требует `composer.write`. */
  readonly composer: {
    insert(text: string): Promise<void>;
  };

  /** Требует `media.read` для нужного типа. */
  readonly media: {
    /** Распознавание речи на устройстве средствами приложения. */
    transcribe(media: Mg.MediaRef, options?: { language?: string }): Promise<{ text: string; language: string }>;
  };

  /** Только https и только хосты из `net`. Без cookie и без редиректов на другие хосты. */
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
