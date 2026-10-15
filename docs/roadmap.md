# Roadmap

This is the single source of truth for the order of work. It replaces the
stage list from the original architecture plan (October 12) and the milestone
order that [parity.md](parity.md) first shipped with. The per-feature backlog
stays in [parity.md](parity.md); every item there carries one of the
milestones below.

Updated 2026-10-15.

## Principles

- **Premium first.** Every milestone ships polished: purposeful animation,
  pixel-exact spacing and type, calm native-Mac feel. A feature that works
  but looks unfinished is not done.
- **Official client as the baseline.** Behaviour and UI basics follow
  [TelegramSwift](https://github.com/overtake/TelegramSwift). It is GPL v2, so
  we study it and write our own code on TDLib.
- **Order.** Daily-use basics first, then what makes Mollygram different
  (privacy, media quality, plugins), then the long tail of management and
  settings, then calls and the macOS release. Everything else from the
  official client comes after the release.

## Order

| # | Milestone | Status | Goal | Done when |
|---|---|---|---|---|
| — | Prototype | done (#4), removed from the repo once the app existed | Glass, 5000-message feed, 640 circle at 120 fps | p99 frame time under 8.3 ms on ProMotion: 119–120 fps on 120 Hz (1x and ProMotion 2x) and 165 fps on 165 Hz, under 1% missed vsyncs, raster p95 under 6 ms, blur about 0.5 ms; media_kit and AVFoundation equal |
| — | Foundation and sign-in | done (#5, #16, #24) | Monorepo, TDLib FFI and generated types, QR/phone/2FA sign-in, chat list and folders | Release build signs in, 500+ chats scroll smoothly, restart keeps the session |
| — | Tabs, split, palette | done (#17, #27, #28) | Workspace model, ⌘K palette with `>` `@` `#`, layout restore | Tabs and split survive a restart |
| M1 | Daily driver | in progress | Notifications, unread handling and jumps, statuses, chat list actions and archive, emoji and stickers, voice recording, rich text, links, profiles, basic settings | A week of daily use instead of the official client with no crash |
| M2 | Full chat | in progress | Every message type can be sent, gallery viewer, search inside chats, shared media, topics, comments, bots | Nothing you can do in a TelegramSwift chat is missing |
| M3 | Privacy extras | not started | Ghost mode, saved deleted messages, edit history, local encrypted store, EXIF stripping, risky switches from [forks-research.md](forks-research.md) | A second-account test shows no read, typing or online leaks in ghost mode, and a deleted message stays visible with a mark |
| M4 | Media quality | partial | Circle recording at up to 640×640 and 120 fps, uncompressed sending by default, media editor, parallel downloads, PiP | A circle recorded in Mollygram plays correctly in the official iOS and Android clients |
| M5 | Plugins | partial (#6, #18) | Install from file, update consent, the three mock plugins (code highlight, quiet hours, translator), app services for plugins | A hostile test plugin cannot leave its permissions or stall the UI |
| M6 | Chats and account management | not started | Create and manage groups and channels, admin tools, contacts, own profile, privacy settings, folder editor, secret chats, multiple accounts | Everything in TelegramSwift's chat and account management is there |
| M7 | Settings parity | not started | Every section of official Settings: notifications, data and storage, appearance, language, passcode, proxy, stickers | Settings walk-through against TelegramSwift finds nothing missing |
| M8 | Calls and macOS release | research done, native lib builds (#13, #20, #22) | 1:1 audio and video calls, screen sharing ([calls.md](calls.md)); signing, notarization, Sparkle auto-update with a beta channel | A 30-minute video call with official iOS holds; a `v*` tag gives installers that open without Gatekeeper warnings and update the previous version |
| M9 | After release | — | Windows and Linux builds polished; group calls and live streams; Telegram platform: stories, Premium, mini apps, payments and Stars, Business, Instant View, statistics; deleted-message sync across devices | — |

Milestones run in this order, but small items may be pulled forward when
they unblock others. Work already done ahead of its milestone (the plugin
sandbox, circle playback, the calls native library) stays as it is.

### Renumbering

The first version of parity.md used a different order. Old to new:
M1→M1, M2→M2, M5→M3, M3→M6, M4→M7, M6→M8, M7→M9. M4 Media quality and M5
Plugins are new; their items moved out of M2 and the "on top of the official
client" section.

## What changed against the original plan

The original plan (stages 1–8) and the first parity.md disagreed in a few
places. This is how they were settled.

| Topic | Original plan | First parity.md | Now |
|---|---|---|---|
| Privacy features | Stage 5, right after tabs | M5, after settings | M3, right after full chat |
| Media quality | Stage 6, before plugins | Spread over M2 | M4, its own milestone |
| Plugins | Stage 7 | Not a milestone | M5, its own milestone |
| Proxy, archive, folder editor | Stage 2 foundation | M1 archive, M3 folders, M4 proxy | Archive M1, folders M6, proxy M7 (TDLib proxy is a settings page, not foundation) |
| Multiple accounts | Stage 4 with tabs | M3 | UI in M6; per-account data folders as an early M1 tech item (see below) |
| Secret chats | Stage 5 privacy | M3 | M6 |
| Stories, Premium, mini apps, payments | Stages 6–7 | M7 | M9, after release |
| Group calls and live streams | Stage 8, in the release | M6 | M9; v1 is 1:1 calls and screen sharing, as decided on 2026-10-14 |
| Chat stage | One stage: text, media, stickers, voice, search, notifications | Split into M1 and M2 | M1 and M2 |

## Architecture drift

Decisions from the original plan checked against `main` on 2026-10-15.

| Decision | In `main` | Action |
|---|---|---|
| TDLib via own `dart:ffi` binding, receive loop in an isolate, types generated from `td_api.tl`, version pinned | Yes: `packages/tdlib`, TDLib 1.8.68 pinned in `tdlib.json`, `tdlib.yml` builds `libtdjson` | None |
| TDLib database key in the OS keychain | Yes: `flutter_secure_storage` in `tdlib_desktop_configuration.dart` | None |
| Riverpod for app state, Workspace model instead of routes | Yes: Riverpod in `packages/app`, `packages/shell` uses plain `ValueNotifier` | None |
| Glass through one `BackdropGroup` and `BackdropFilter.grouped` | Yes: `packages/ui_kit/lib/src/glass/glass.dart` | None |
| media_kit for video, AVFoundation decoder as fallback | Yes: `packages/media` on media_kit | None |
| QuickJS-ng plugins with manifest permissions | Yes: `packages/plugin_host`, built-in Filters and Translate | None |
| Messages as bubbles with precomputed heights | Changed: flat no-bubble layout like TelegramSwift (decision 2026-10-14) | Plan text updated |
| Message list as a `CustomScrollView` anchored on a message id, paging both ways | Yes: `TimelineView` with `TimelineScrollController`, `loadAround` and `loadNewer` in core | Done with the unread work |
| One command registry (`Actions`/`Intents`) for palette, menus, shortcuts, plugins and `tg://` links | Not yet: palette commands are a list in `packages/shell` | Build with link handling in M1 |
| Multi-account ready: one client id and data folder per account | Yes: `accounts/<slot>/` with an index and a keychain key per slot (`account_storage.dart`); the old `tdlib/` folder is moved on first launch | Account switching UI in M6 |
| Own drift + SQLCipher database for deleted messages, edit history, workspace, plugin data | Not yet; the workspace is saved to `workspace.json` | Database lands with M3; the workspace can stay in JSON |
| Ghost mode as one filter on outgoing TDLib requests | Not yet: `viewMessages` is called directly from `ConversationController` | Route through one filter in M3 |
| Windows and Linux builds on every PR | Changed: desktop builds run on `main` and on PRs labelled `full-ci` (#12) | Accepted to save CI time |
| macOS integration tests and a frame-budget check in CI | Not yet: frame numbers come from `packages/media/example` on a real Mac | Add before M8; the removed prototype's glass + feed benchmark (`prototype/lib/perf` in #4) is a starting point |

## Not in the plan

- exteraGram plugin compatibility: no (2026-10-12).
- Same design on every OS; v1 is macOS only (2026-10-12).
