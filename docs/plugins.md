# Plugins: specification v1.1

Mollygram plugins are written in TypeScript or JavaScript and run in a quickjs-ng sandbox. Plugins cannot load native code, and there is no exteraGram compatibility. Implementation: `packages/plugin_host`; types for authors: `packages/plugin_sdk`; example: `packages/plugin_host/example/transcribe`; built-in plugins: `packages/plugin_host/builtin`.

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

An unknown field, permission or hook makes the manifest invalid: nothing is silently ignored. The id names the plugin's folder, so device names such as `con` or `nul` are not allowed in it. Errors are collected into a list and shown at install time.

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
| `message.render.text` (1.1) | render | `messages.read: chats[]` or `all` | `{message}` | list of UI nodes shown below the text |
| `message.filter` (1.1) | filter | `messages.read: chats[]` or `all` | `{message}` | `{filter: "hide" \| "collapse", reason}` or nothing |
| `ui.action` | render | | `{action, payload, message}` after a plugin button is pressed | list of UI nodes replacing the old ones |
| `notification.incoming` | intercept | `notifications.manage` | `{chatId, messageId, title, body}` | `{cancel}`, `{modify}` or `{defer: seconds}` |
| `settings.changed` | observe | | `{key, value}` | |

`message.render.code` hands a plugin one code block (a `pre` entity) and its language, not the message: without `messages.read` the host passes `message` on as `{chatId, id}` only, and the app may leave it out. A `code` node is used only when its spans spell exactly the code it was given, so a plugin can color a block but never change what it says; a node has at most 8000 spans of up to 4000 characters each. Code blocks are message text, so a plugin that hooks `message.render.code` and also has `net` must declare `messages.read: all`, and the consent sheet lists the hook ("Message rendering").

Events marked 1.1 arrived in SDK 1.1 for the built-in plugins from `forks-research.md` (items 8 and 9); existing events did not change. A plugin that subscribes to them declares `sdk: ^1.1`, otherwise the manifest is invalid.

Events that carry messages (`chat.opened`, `message.incoming`, `message.edited`, `message.deleted`, `message.render.text`, `message.filter`) reach a `messages.read: chats[]` plugin only for the chats the user granted.

For `message.filter`, the strongest answer of all handlers wins: `hide` over `collapse`. A collapsed message is shown as a thin row with the `reason` (up to 100 characters) that the user can expand; a hidden one is not shown at all.

## Plugin API

The global `mg` object is frozen and cannot be replaced. Full types: `packages/plugin_sdk/index.d.ts`.

```ts
mg.on(event, handler)                     // during load
mg.command("/name", handler)              // a command from the manifest, shown in the ⌘K palette
mg.settings.get(key)                      // synchronous
mg.storage.get / set / delete             // Promise, storage permission
mg.messages.get(chatId, id) / history()   // Promise, messages.read permission
mg.messages.translate(chatId, id, {to})   // 1.1, Promise, messages.read; Telegram's own translation (TDLib translateMessageText)
mg.text.detectLanguage(text)              // 1.1, Promise, no permission; on-device detection, null when unsure
mg.app.locale()                           // 1.1, synchronous: the app's UI language, "en" or "ru"
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

Limits: 200 nodes, nesting depth 8, strings up to 4000 characters, the text of a `text` node up to 16384. No colors, sizes, images or HTML. An invalid tree is discarded and counts as a failure.

## Isolation and limits

- **Separate VM.** Each plugin gets its own quickjs-ng `JSRuntime` without `quickjs-libc`: no files, network, timers, `require`, `std` or `os`. The only way out is a host function that the prelude hides in a closure before the plugin's code runs.
- **Separate isolate.** `PluginWorker` runs the VM in its own Dart isolate. JS never runs on the UI isolate, so even a plugin that hits its time limit does not drop frames. Services (TDLib, storage, speech recognition) are called on the app isolate, which only receives calls that have already been authorized.
- **Memory.** 32 MB heap per plugin (`JS_SetMemoryLimit`). Exceeding it disables the plugin immediately and frees the VM.
- **Stack.** 512 KB (`JS_SetMaxStackSize`); deep recursion throws an exception instead of crashing the process. The stack top is updated before every entry into JS, because the isolate may move to another thread.
- **Time.** CPU time budget per entry into JS: 500 ms for loading, 100 ms for a handler or a promise job run. Measured as thread CPU time, so system load does not penalize well-behaved plugins. An async handler is awaited for up to 5 s; a command or button press for up to 60 s (it may involve speech recognition).
- **Failures.** An exception, timeout or invalid UI is a strike, and the event result is as if the plugin were not installed. Three consecutive strikes disable the plugin until it is re-enabled manually; the reason is shown on its screen. A successful call resets the counter.
- **Not covered.** A bug in quickjs-ng itself (memory corruption) will crash the process, because the VM lives in our process. If this turns out to be a real risk in stage 7, the same worker protocol can move to a separate host process with no changes for plugins.

## Built-in plugins

Shipped with the app in `packages/plugin_host/builtin`, built from TypeScript like any other plugin and run in the same sandbox with the same permission checks. They cannot be uninstalled, only turned off.

- **Filters** (`dev.mollygram.filters`): collapses or hides advertising (`erid` tokens, `#ad`, `#реклама`, a "Sponsored" line) and messages with the user's keywords. Keywords match whole words in any script, ignoring case. Permissions: `messages.read: all`; no network, no storage.
- **Translate** (`dev.mollygram.translate`): not installed. Translation moved into the chat itself, a bar under the header that translates the whole conversation in place, so the per-message "Translate from German" link is gone. The plugin's sources stay in `builtin/translate` as a worked example of the `message.render.text` hook, `text.detectLanguage` and `messages.translate`, which plugins can still use.

- **Code highlight** (`dev.mollygram.codehighlight`): colors code blocks in messages through `message.render.code`. Knows the keywords, comments and strings of the common languages (JavaScript and TypeScript, Dart, Python, Go, Rust, C-like, Java-like, shell, SQL) and falls back to the keywords they share. Permissions: none.

Rebuild after editing `src/index.ts`: `cd packages/plugin_host/builtin/<name> && npx -p typescript@5.9 tsc -p .`. CI checks that the committed `index.js` matches.

## Plugin settings screen

The Plugins page of the settings window (`packages/app/lib/src/settings/plugins_page.dart`) uses the shared settings widgets: installed and available plugins as rows, and a page per plugin with its switch, access, options, commands, manifest and uninstall. Installing from a file, or an update that asks for more access, opens a consent sheet listing every permission (for an update, only the new ones); `messages.read: all` gets a separate warning. The state and texts come from `packages/plugins_ui` (`PluginsController`, `PluginsStrings`): permission rows and the built-in plugins' texts are localized in English and Russian; third-party plugins show their manifest texts as is. `packages/plugins_ui` also keeps the standalone screen from `design/Plugins.dc.html`.

## Running in the app

`packages/app/lib/src/plugins` connects the sandbox to the app:

- **Installing.** "Install from file…" asks for a plugin's `manifest.yaml` (no other file is accepted); its folder is loaded with `PluginBundle.load`, so an invalid manifest, a manifest or code linked from outside the folder, or code over 2 MB is refused with the host's errors. Nothing is copied until the user allows the access, and only the exact manifest the user approved is installed: a declined install is forgotten, and a failed copy leaves nothing installed and says why. The manifest and code are then copied to `plugins/bundles/<id>` in the app support folder, so the plugin no longer depends on the original file. The copy is written next to the old one and swapped in, and a folder is only loaded when its manifest has the folder's id. Choices (on or off, settings, update time) are kept in `plugins/state.json`; an unreadable one is kept aside as `state.json.bak`.
- **Updating.** Picking a plugin that is already installed is an update. An older version or the same version is refused; a newer one that asks for nothing new replaces the old at once; one that asks for more waits on the plugin's page ("Version 1.1.0 asks for more access", Review…), and the old version keeps running until the user allows the new access.
- **Running.** A plugin runs in a `PluginWorker` only once the app has an event it hooks or the user runs one of its commands, and only for the events the app delivers so far: `message.render.code`, `message.render.text`, `message.filter` and `ui.action` for its own buttons. Turning it off, updating or uninstalling stops it; the host disabling it, after failures or a load error, is shown on its page. The app also gives up on a plugin that does not start within 10 s or answer within 6 s, and a worker isolate that exits is reported as disabled. A plugin that fails to start is tried again after 10, 20 s, and turned off with the reason after 3 failures in a row. `messages.read: chats[]` plugins get no events yet: there is no screen to grant chats.
- **Services.** `storage` keeps a JSON file per plugin, `plugins/data/<id>.json`; a write that would make the file larger than the manifest's `storage` size fails with `quota_exceeded` and changes nothing, and uninstalling deletes the file. Sizes are kept per key, and the file is encoded and written in a background isolate, writes close together folded into one. `messages.translate` asks Telegram (`translateMessageText`), failing with `translation_failed`. `text.detectLanguage` runs on the device (`detectLanguage` in `plugin_host`: the script, letters unique to a language and common short words) and answers null when unsure. `ui.toast` is accepted and not shown yet; everything else fails with `unavailable`.
- **Code blocks.** `FormattedTextView` asks the running plugins for each `pre` block of a message (up to 4096 characters), in install order, and colors it with the first valid answer, using the theme's colors for each token.
- **Messages.** The timeline asks `message.filter` plugins about every loaded message with text (`PluginVerdicts`; the chat list can use `messageVisibilityProvider`): the strongest answer wins and an invalid answer counts as none. A hidden message leaves the list, so runs and dates join up; a collapsed one becomes a line with the reason and "Show", which stays shown; a message whose answer is not known yet keeps its place undrawn, so it never flashes. Answers are cached per message text, so an edit is asked about again. Under the text it draws what `message.render.text` plugins return (`PluginMessageExtras`) with the app's own widgets (`PluginUiView`); a click on a plugin's button is sent to that plugin as `ui.action` with the message, and its answer replaces what it showed. What plugins render is cached per message and dropped when a plugin or its settings change. Translate keeps its last 400 translations and lets the oldest go when its storage is full.
- **Commands.** The commands of the plugins that are on are listed in the ⌘K palette under the owner `plugins`, with the plugin's name, and run in the chat in front. Manifest shortcuts are shown on the plugin's page and not bound yet.
- **Log.** Each plugin's page has a Log page with its last 200 lines from this run of the app, each cut to 1000 characters and sent from the worker in batches, (`mg.log`, `console.*`, failures and why it was turned off) and a Copy button.

## Distribution

v1: install from a file, plus built-in plugins shipped by us. A catalog (item 16 of the forks research) comes later: a signed index, permissions shown before install, no code loaded from the network at runtime.

## Example: "Transcribe"

`packages/plugin_host/example/transcribe`. Shows a "Transcribe" button under voice and video messages; when pressed, it asks the app to recognize speech on device, caches the text in plugin storage and displays it. With the "Transcribe automatically" setting enabled, it does this at render time. Permissions: `media.read: [voice, round]` and `storage: 1mb`; no network.

The `design/Plugins.dc.html` mockup had `runtime: native` for this plugin; it has been corrected to `js`, since recognition is done by the app, not by plugin code.
