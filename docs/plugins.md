# Plugins: specification v1

Mollygram plugins are written in TypeScript or JavaScript and run in a quickjs-ng sandbox. Plugins cannot load native code, and there is no exteraGram compatibility. Implementation: `packages/plugin_host`; types for authors: `packages/plugin_sdk`; example: `packages/plugin_host/example/transcribe`.

## Prior art

| Where | How it works | What we take | What we avoid |
|-------|--------------|--------------|---------------|
| exteraGram (Android) | Python via Chaquopy with hooks on Java methods. Hooks `pre_request_hook`, `post_request_hook`, `on_update_hook`, `on_send_message_hook`; a `HookResult` with `CANCEL`/`MODIFY`/`MODIFY_FINAL` strategies. Menus via `add_menu_item`, settings via `create_settings()`. Metadata `__id__`, `__name__`, `__sdk_version__` | Intercepting sends with cancel and modify, handler priority, declarative settings, SDK version range | No permissions at all: a plugin sees the whole process and the session. TL schema names used as the API break on every update. `MODIFY_FINAL` lets one plugin disable all others |
| AyuGram, Nekogram, Swiftgram, tdesktop desktop forks | No plugins; everything is built in and toggled by switches | A list of features that fit plugins well: filters, translation (see `forks-research.md`, items 8, 9) | |
| Figma | Plugin code is bare JS with no DOM, `fetch` or timers; UI is separate; `networkAccess` in the manifest | A bare engine with everything going through the host API, a host allowlist, the user can stop a plugin | |
| Chrome MV3 | Permissions declared up front in the manifest; an update that adds permissions disables the extension until the user consents | Re-consent when permissions expand | |
| VS Code, Obsidian, Vencord | Full access to Node or to the client internals | Lazy activation on declared events | Trust instead of permissions, patching internals |

Sources: plugins.exteragram.app/docs, docs.ayugram.one, developers.figma.com/docs/plugins/how-plugins-run, developer.chrome.com/docs/extensions/develop/concepts/permission-warnings.

## Plugin package

A folder with two files:

```
manifest.yaml
index.js        # a single file, bundled from TS by any bundler as a script (IIFE)
```

`import`, `require` and modules are not supported. Code size is limited to 2 MB. `main` cannot point outside the folder; symlinks leading outside are rejected.

## Manifest

```yaml
id: dev.mollygram.transcribe   # reverse domain notation, at least three parts
name: Transcribe               # up to 40 characters
version: 1.0.0                 # semver
author: Mollygram
description: Transcribes voice and video messages on device.
runtime: js                    # the only allowed value
sdk: ^1.0                      # compatible within the major version
main: index.js                 # defaults to index.js
permissions:
  media.read: [voice, round]
  storage: 1mb
hooks: [message.render.voice, message.render.round]
commands:
  - { name: /summary, title: Summarize current chat, shortcut: cmd+shift+s }
settings:
  - { key: auto, type: toggle, label: Transcribe automatically, default: false }
  - key: language
    type: select
    label: Language
    default: auto
    options: [{ value: auto, label: Auto-detect }, { value: en, label: English }]
```

An unknown field, permission or hook makes the manifest invalid: nothing is silently ignored. Errors are collected into a list and shown at install time.

## Permissions

| Permission | Values | What it allows | Line on the "Access" screen |
|------------|--------|----------------|-----------------------------|
| `messages.read` | `on_command` | Read the current chat while a user-invoked command is running | Messages in the current chat. Only when you run a command |
| | `chats[]` | Read chats from a list the user sets in the plugin's settings | Messages in selected chats |
| | `all` | All chats; a separate warning is shown at install time | All messages |
| `composer.write` | `true` | Insert text into the composer and intercept sending | Composer |
| `net` | list of hosts, `user_endpoint` | `https` to exact host names; `user_endpoint` allows an address the user enters themselves. Wildcards and IPs are not allowed | Network: api.deepl.com |
| `storage` | `512kb` … `50mb` | Private key-value storage | Storage. Up to 5 MB |
| `notifications.manage` | `true` | Defer and group notifications | Notifications |
| `media.read` | `[voice, round, photo, video, document]` | Process media of these types through the host API | Media: voice messages, video messages |

Never available: TDLib keys and session, raw MTProto, the file system, other plugins, other accounts, cookies.

Consent is given at install time for the whole list. If an update adds permissions (`PermissionSet.escalationsFrom`), the new version stays disabled until the user consents again. Auto-updates that add permissions are not allowed.

## Events

A plugin subscribes with `mg.on(event, handler)`, only during load and only to events listed in the manifest's `hooks` (except `ui.action`, `settings.changed` and `app.ready`, which are available to everyone). Handlers within one plugin run in order; plugins are called in install order, and none of them can prevent the next ones from being called.

| Event | Kind | Required permission | Data | Response |
|-------|------|---------------------|------|----------|
| `app.ready` | observe | | | |
| `chat.opened` | observe | `messages.read: chats[]` or `all` | `{chatId}` | |
| `message.incoming` | observe | same | `{message}` | |
| `message.edited` | observe | same | `{message, oldText}` | |
| `message.deleted` | observe | same | `{chatId, messageIds}` | |
| `message.sending` | intercept | `composer.write` | draft `{chatId, text, replyTo}` | `{modify: draft}` or `{cancel: true}` |
| `message.render.code` | render | | `{message, language, code}` | list of UI nodes |
| `message.render.voice` | render | `media.read: [voice]` | `{message}` | list of UI nodes |
| `message.render.round` | render | `media.read: [round]` | `{message}` | list of UI nodes |
| `ui.action` | render | | `{action, payload, message}` after a plugin button is pressed | list of UI nodes replacing the old ones |
| `notification.incoming` | intercept | `notifications.manage` | `{chatId, messageId, title, body}` | `{cancel}`, `{modify}` or `{defer: seconds}` |
| `settings.changed` | observe | | `{key, value}` | |

Planned for stage 7, for the built-in plugins from `forks-research.md`: `message.filter` (intercepts display to hide or collapse a message; requires `messages.read`) for ad filters, and `message.render.text` (a block below the text) for translation. They will ship in SDK minor version 1.1 without changing existing events.

## Plugin API

The global `mg` object is frozen and cannot be replaced. Full types: `packages/plugin_sdk/index.d.ts`.

```ts
mg.on(event, handler)                     // during load
mg.command("/name", handler)              // a command from the manifest, shown in the ⌘K palette
mg.settings.get(key)                      // synchronous
mg.storage.get / set / delete             // Promise, storage permission
mg.messages.get(chatId, id) / history()   // Promise, messages.read permission
mg.composer.insert(text)                  // Promise, composer.write permission
mg.media.transcribe(media, {language})    // Promise, media.read permission; the app does on-device recognition
mg.net.fetch(url, {method, headers, body})// Promise, https and hosts from net only, no cookies, no redirects to other hosts
mg.ui.toast(text)
mg.log(...) and console.log/info/warn/error  // plugin log, shown on the plugin's screen
```

Host errors are thrown as exceptions with a `code` field: `permission_denied`, `bad_argument`, `no_method`, `host_failure`, or a service-specific code.

## Declarative UI

A plugin does not draw anything itself; it returns a node tree, and the app renders it with its own widgets in the app's style. This way a plugin cannot fake a system dialog and does not break the design.

| Node | Fields |
|------|--------|
| `text` | `text`, `style: body \| secondary \| mono` |
| `button` | `label`, `action`, `payload` |
| `toggle` | `label`, `action`, `value` |
| `progress` | `label` |
| `row`, `column` | `children` |
| `code` | `language`, `spans: [{text, token}]`; tokens come from the theme only: `keyword`, `string`, `number`, `comment`, `function`, `type`, `punctuation`, `plain` |

Limits: 200 nodes, nesting depth 8, strings up to 4000 characters. No colors, sizes, images or HTML. An invalid tree is discarded and counts as a failure.

## Isolation and limits

- **Separate VM.** Each plugin gets its own quickjs-ng `JSRuntime` without `quickjs-libc`: no files, network, timers, `require`, `std` or `os`. The only way out is a host function that the prelude hides in a closure before the plugin's code runs.
- **Separate isolate.** `PluginWorker` runs the VM in its own Dart isolate. JS never runs on the UI isolate, so even a plugin that hits its time limit does not drop frames. Services (TDLib, storage, speech recognition) are called on the app isolate, which only receives calls that have already been authorized.
- **Memory.** 32 MB heap per plugin (`JS_SetMemoryLimit`). Exceeding it disables the plugin immediately and frees the VM.
- **Stack.** 512 KB (`JS_SetMaxStackSize`); deep recursion throws an exception instead of crashing the process. The stack top is updated before every entry into JS, because the isolate may move to another thread.
- **Time.** CPU time budget per entry into JS: 500 ms for loading, 100 ms for a handler or a promise job run. Measured as thread CPU time, so system load does not penalize well-behaved plugins. An async handler is awaited for up to 5 s; a command or button press for up to 60 s (it may involve speech recognition).
- **Failures.** An exception, timeout or invalid UI is a strike, and the event result is as if the plugin were not installed. Three consecutive strikes disable the plugin until it is re-enabled manually; the reason is shown on its screen. A successful call resets the counter.
- **Not covered.** A bug in quickjs-ng itself (memory corruption) will crash the process, because the VM lives in our process. If this turns out to be a real risk in stage 7, the same worker protocol can move to a separate host process with no changes for plugins.

## Distribution

v1: install from a file, plus built-in plugins shipped by us. A catalog (item 16 of the forks research) comes later: a signed index, permissions shown before install, no code loaded from the network at runtime.

## Example: "Transcribe"

`packages/plugin_host/example/transcribe`. Shows a "Transcribe" button under voice and video messages; when pressed, it asks the app to recognize speech on device, caches the text in plugin storage and displays it. With the "Transcribe automatically" setting enabled, it does this at render time. Permissions: `media.read: [voice, round]` and `storage: 1mb`; no network.

The `design/Plugins.dc.html` mockup had `runtime: native` for this plugin; it has been corrected to `js`, since recognition is done by the app, not by plugin code.
