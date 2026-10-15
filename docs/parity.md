# Feature parity with the official macOS client

This is the backlog for reaching feature parity with the official macOS
Telegram client, [TelegramSwift](https://github.com/overtake/TelegramSwift).
TelegramSwift is GPL v2: we study how it behaves and looks, and write our
own code on TDLib. Nothing is copied from it.

Audited against `main` on 2026-10-15 (after #32). Status is read from the
code, so "done" means implemented, not that every edge case is covered.

- **Status**: `done`, `partial` (works but is missing parts the official
  client has), `missing`.
- **Size**: `S` up to a day, `M` a few days, `L` a week or more.
- **M**: the milestone the item belongs to (see the order below).

## Milestones

The milestones and their order live in [roadmap.md](roadmap.md):
M1 daily driver, M2 full chat, M3 privacy extras, M4 media quality,
M5 plugins, M6 chats and account management, M7 settings parity,
M8 calls and macOS release, M9 after release.

### First items to take

1. ~~Desktop notifications with reply and mark as read (M1)~~ done
2. Unread jump: "new messages" separator, scroll-to-bottom button with a counter, jump to mentions and reactions (M1)
3. Typing, online and last-seen statuses in the header and chat list (M1)
4. Chat list context menu: pin, mute, archive, mark as read, delete or leave, plus the archive folder (M1)
5. Emoji and sticker picker in the composer (M1)

## Backlog

### Chat list and folders

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Chat list with last message, time, unread count, muted state | done | `ChatListTile`, `ChatListStore` | | |
| Folder tabs | done | Read-only tabs from `UpdateChatFolders` | | |
| Paging the chat list | done | `loadMore` | | |
| Chat list context menu: pin, mute, archive, mark read/unread, clear, delete, leave | missing | `ToggleChatIsPinned`, `SetChatNotificationSettings`, `AddChatToList`, `ToggleChatIsMarkedAsUnread` | M | M1 |
| Archive folder entry and archive view | partial | `ChatListLocation.archive` exists, no UI entry | S | M1 |
| Unread mention and reaction badges in the list | missing | `unreadMentionCount`, `unreadReactionCount` | S | M1 |
| Typing and online dot in the list | missing | `UpdateChatAction`, `UpdateUserStatus` | S | M1 |
| Draft preview in the list ("Draft: …") | partial | `UpdateChatDraftMessage` is stored, not shown | S | M1 |
| Pinned chats order with drag | missing | `SetPinnedChats` | S | M6 |
| Folder editor: create, edit, delete, reorder, include/exclude, recommended | done | Settings > Chat folders: drag reorder, editor sheet with icon, chat types and a chat picker, delete with chats to leave, recommended folders; `ChatFoldersController` in core. No pinning inside a folder or "All chats" position yet | | M6 |
| Folder sidebar (vertical tabs) and folder icons | missing | Official offers left-side folders | M | M7 |
| Shared folders (chat folder invite links) | missing | `CreateChatFolderInviteLink` | M | M9 |
| Saved Messages as a list of sub-chats | missing | Saved Messages tags and per-source chats | M | M2 |
| Contacts birthdays and suggestions in the list | missing | | S | M9 |

### Opening and reading chats

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| History with paging, flat no-bubble layout | done | #24, #29 | | |
| Read receipts sent on view | done | `ViewMessages` | | |
| Read ticks on outgoing messages | done | `UpdateChatReadOutbox` | | |
| "New messages" separator and opening at the first unread | done | Unread PR: `TimelineView` grows both ways from the first unread | | |
| Scroll-to-bottom button with unread counter | done | Unread PR | | |
| Jump to next mention and reaction | done | Unread PR: `SearchChatMessages` with the unread filters | | |
| Pinned message bar with cycling and the pinned list | done | Bar with cycling, pin and unpin from the menu, the list behind the bar's button with Unpin all | S | M2 |
| Jump to a replied message and back | done | Jump with a highlight; the down button returns to where the user was | | |
| Date headers and sticky date | done | Date pills, and the top row's date floats while scrolling | | |
| Jump to date (calendar) | done | Click a date pill: calendar, `getChatMessageByDate`; no media calendar | M | M2 |
| Header status: online, last seen, members, typing | done (#40) | | S | M1 |
| Join and mute buttons for channels and groups you are not in | done | Join in place of the composer; Mute and Unmute in channels you only read | | |
| Open `t.me` and `tg://` links, usernames, hashtags, bot commands | done | `links/`: links, mentions and mentions by name, invites, `tg://user?id=`, `t.me/s/` previews, message links jump to the message; hashtags open the ⌘K message search, bot commands are sent to the chat | | |
| Link previews in messages | partial | Check `MessageText.linkPreview` rendering | M | M1 |
| Text selection across messages | done | Mouse selection over the timeline, copy with the shortcut | M | M2 |
| Multi-select mode: forward, delete, copy several | done | Select from the menu, click rows, bar in place of the composer; no shift-click range yet | M | M2 |
| Forum topics: topic list, topic chat, create and close topics | missing | Service messages render only | L | M2 |
| Channel comments (discussion thread) | missing | `GetMessageThread` | M | M2 |
| Reply threads in groups | missing | | M | M2 |
| Secret chats | partial | Start from New message (Secret chat) or a person's info panel; state pending, ready or closed (`SecretChatsController`); encryption key sheet with the 12×12 key picture and hex, as the official apps draw them; self-destruct timer (off, 1 s to 1 week) and Close in the palette for the focused secret chat; closed bar with Delete chat. The chat header capsule, chat list row and header menu consume `secretChatProvider`, `SecretChatLock` and the sheets from `secret/secret_chat.dart`, wired by the chat and sidebar work | L | M6 |
| Secret chat screenshot blocking | done | The window is kept out of screenshots and screen recordings while any pane of the active tab shows a secret chat (macOS `sharingType = .none`, best effort on macOS 15 and later, where some capture APIs ignore it; Windows and Linux not yet). Privacy extras, "Allow screenshots in secret chats" (off, risky) skips it | S | M3 |
| Spoilers, custom emoji in text | partial | `concealed.dart` covers spoilers; custom emoji need sticker rendering | M | M2 |
| Polls and quizzes: vote, results | partial | Rendered; voting unverified | M | M2 |
| Checklists (todo messages) | missing | `ChatTodoItem` | S | M9 |
| Dice and slot animations | partial | | S | M9 |
| Live location view | missing | | M | M2 |
| Auto-translate and "Translate" in the menu | missing | Built-in Translate plugin planned | M | M5 |
| Voice message transcription | missing | `RecognizeSpeech` (Premium) | S | M9 |
| Message effects and reaction animations | missing | | M | M9 |
| Sponsored messages in channels | missing | Required by Telegram API terms | S | M2 |

### Message actions

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Reply, edit, delete (for me / for everyone), forward, copy text, copy link | done | #30 | | |
| Quick reactions and toggling reactions | done | #30 | | |
| Full reaction picker (all emoji, custom reactions) | partial | Chevron in the reaction bar opens a grid of every emoji reaction TDLib offers; custom emoji reactions wait for sticker rendering | S | M2 |
| Reply with quote (part of the text) | done | Select text, Quote in the menu | S | M2 |
| Pin and unpin | done (#49) | | S | M1 |
| Forward without author or caption | done | Checkboxes in the forward picker | S | M2 |
| Save media to Downloads, show in Finder | done | Message menu: Save as, Save to Downloads (the chosen folder, numbered when taken), Show in Finder for a downloaded file; photos, videos, GIFs, files, music, voice and video messages, stickers | | |
| Report message | done | `ReportChat` step by step: reason, sub-reason, details, toast (`chat/report.dart`) | | |
| Who read and who reacted | done | Rows at the top of the message menu, read time in private chats | S | M2 |
| Message info: view count, forwards, edit date | done | Views and forwards on channel posts, full date and edit time on hover | S | M2 |
| Select and copy part of a message | done | | | M2 |

### Composer

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Text, Enter to send, Shift+Enter newline | done | | | |
| Attach photos, videos, files: pick, drop, paste, albums | done | #31 | | |
| Edit mode and reply panel | done | #30 | | |
| Drafts saved to the server and synced | done | Composer loads the chat's draft and saves its own (text, formatting, reply) after a pause and on leaving | | |
| Emoji picker | done | #34: groups, recent, keyword search | | |
| Sticker panel, recent and favourite stickers, sticker search | partial | #34: recent, favourites, installed sets; no search; sets are managed in Settings > Stickers and emoji | S | M1 |
| GIF panel and GIF search | missing | `GifKeyboardController` | M | M2 |
| Emoji and sticker suggestions while typing | missing | `InputSwapSuggestionsPanel` | M | M2 |
| Rich text formatting: bold, italic, code, link, spoiler, quote; Markdown shortcuts | done | `RichTextEditingController` in ui_kit: ⌘B, ⌘I, ⌘U, ⌘⇧X, ⌘⇧M, ⌘⇧P, ⌘⇧., ⌘K, context menu; Markdown converted on send. Captions of files are still plain | | |
| Mentions autocomplete (@) | done | `MentionSearch` with `ChatMembersFilterMention`; no `:` emoji shortcodes yet | | |
| Bot command autocomplete (/) and bot keyboards | missing | `ReplyMarkupNode` | M | M2 |
| Inline bots (@gif, @vid) | missing | `GetInlineQueryResults` | M | M9 |
| Voice message recording | done | Hold, lock, cancel; Opus in Ogg via AudioToolbox on macOS | M | M1 |
| Video message (circle) recording | partial | Hold, lock, cancel, 60 s limit; 640×640 H.264 via AVFoundation on macOS. Front camera only, no flip or preview before sending | L | M4 |
| Silent send and scheduled messages, scheduled list | partial | Right click or long press on Send: without sound, or at a day and time; a clock in the composer opens the scheduled list with Send now, Reschedule and Delete; sending media later is still missing | S | M2 |
| Send as (channel identity) | missing | `ChatInputSendAsView` | S | M6 |
| Polls and quizzes creation | missing | `NewPollController` | M | M2 |
| Location and venue sending | missing | | M | M2 |
| Contact sending | missing | | S | M2 |
| Send preview: caption, send as files, albums | done | #31 | | |
| Send preview: spoiler, self-destruct timer, compression choice | missing | `hasSpoiler`, `selfDestructType`; uncompressed default planned | S | M2 |
| Media editor: crop, rotate, flip, aspect presets | done | `packages/media_editor` | | |
| Media editor: drawing (pen, marker, arrow, eraser, colours, thickness) | done | `packages/media_editor` | | |
| Media editor: text, stickers and emoji placed on the image | done | `packages/media_editor`; stickers from the user’s packs through the app’s picker (animated ones as stills) | | |
| Media editor: arrows and shapes, blur and pixelate brush | done | `packages/media_editor` | | |
| Media editor: filters and adjustments (brightness, contrast, saturation, warmth, vignette) | done | `packages/media_editor`: seven looks, six sliders | | |
| Video editor: trim, mute, cover frame, quality | partial | `packages/media_editor`: trim, mute and cover done (macOS, AVFoundation); quality presets pending | S | M4 |
| Slowmode and restriction notices | done | Members who may not write see why instead of the composer; slowmode counts down under it (`chat/slow_mode.dart`) | | |
| Link preview control (remove, above/below) | done | The composer shows the preview of the first link in the draft, with a button to put it above the text and one to drop it; the choice goes with the draft and the message | | |

### Media

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Photos, videos, GIFs, stickers (WebP, TGS, WebM) in chat | done | #29 | | |
| Voice messages playback with waveform | done | | | |
| Video circles playback at 120 fps | done | `packages/media` | | |
| Files and music: download, open, cancel | done | | | |
| Fullscreen media viewer on a dimmed backdrop, open and close animation | done | Viewer PR | | |
| Viewer: arrows and swipe between the chat's photos and videos, thumbnail strip | partial | Viewer PR: arrows and keys over `SearchChatMessages`; no swipe, no thumbnail strip | S | M2 |
| Viewer: zoom (pinch, scroll, double click) and pan, rotate | partial | Viewer PR: zoom and pan; no rotate | S | M2 |
| Viewer: video scrubbing, loop, playback speed, volume, fullscreen | partial | Viewer PR: scrubbing, loop, speed, mute; plays once downloaded, no streaming | S | M2 |
| Viewer: GIFs and video stickers looped | partial | Viewer PR: GIFs looped; video stickers not yet | S | M2 |
| Viewer: save, copy, forward, delete, show in chat, keyboard shortcuts | partial | Viewer PR: save, copy, forward, Esc, arrows, Space, ⌘S, ⌘C; no delete or show in chat | S | M2 |
| Global audio player with playlist and header bar | missing | `InlineAudioPlayerView` | M | M2 |
| Picture-in-picture for video and circles | missing | `PIPVideoWindow` | M | M4 |
| Voice playback speed and continuous play | partial | Speed 1×, 1.5×, 2× and waveform scrubbing done; continuous play missing | S | M1 |
| Downloads manager (list, pause, show in Finder) | missing | `DownloadsController` | M | M7 |
| Autodownload rules | missing | Data and storage | M | M7 |
| Quick Look for documents | missing | | S | M2 |

### Search

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Chat search in the sidebar and ⌘K palette | done | `chat_search.dart`, #27 | | |
| Global message search | partial | `SearchMessages` used by the palette; no jump to the message | M | M2 |
| Search inside a chat, by sender, by date | partial | ⌘F capsule with result arrows (`chat_search/`); sender filter in core only, no date jump | S | M2 |
| Hashtag and cashtag search | partial | A tapped hashtag or cashtag opens the ⌘K message search with it; no dedicated hashtag results view | S | M2 |
| Search filters (media, links, files, voice) | partial | `ChatSearchController` filters back the shared media tabs; not offered in ⌘F yet | S | M2 |
| Recent searches and top peers | missing | | S | M2 |

### Profiles and info panels

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| User profile: photo, bio, username, phone, birthday, actions | done | `PeerInfoController` in core, inspector panel in `app/lib/src/profile` | | |
| Group and channel info: description, link, members count | done | First 50 members, most recently active first | | |
| Shared media tabs: media, files, links, voice, music, GIFs, groups in common | partial | `SharedMediaView` has media, files, links, voice, music; GIFs and groups in common missing; in the info panel | M | M2 |
| Members list with search | done | Info panel (`profile/`): owner and admins first, then online; search and Show more pages through `getSupergroupMembers` | | |
| Profile photo gallery | missing | | S | M2 |
| Per-chat notifications and auto-delete timer | partial | Mute and unmute in the info panel; no mute-for durations, no auto-delete | S | M1 |
| Block, report, share contact | partial | Block and unblock in the info panel | S | M6 |

### Groups, channels and admin tools

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Create group and channel | partial | ⌘K New group (contacts, then a name) and New channel (name, description); no photo or public link at creation | S | M6 |
| Edit title, photo, description, username, public/private | partial | Edit sheet for title, description and photo; username and public/private missing | S | M6 |
| Add, remove, ban members; admin rights and titles | partial | Member context menu: make admin with a rights sheet, edit or dismiss, restrict, remove; adding members to an existing group and admin titles missing | M | M6 |
| Group permissions, slow mode | missing | `ChannelPermissionsController` | M | M6 |
| Invite links: create, revoke, join requests | partial | Primary link copy and revoke, additional links with expiry, limit and approval; editing a link and the join request queue missing | S | M6 |
| Leave a group or channel, delete it for everyone | done | Info panel rows with a confirmation; delete only for the owner | | |
| Linked discussion group | missing | | S | M6 |
| Allowed reactions, chat history for new members | missing | | S | M6 |
| Recent actions (admin log) | missing | `ChannelEventLogController` | M | M6 |
| Enable topics in a group | missing | | S | M6 |
| Channel and group statistics | missing | `ChannelStatsViewController` | L | M9 |
| Boosts | missing | | M | M9 |

### Contacts and accounts

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Sign in: QR, phone, code, 2FA password | done | #16, #24 | | |
| Sign up (new account), email code, account reset | partial | Unsupported steps show a notice | M | M6 |
| Contacts list, add and edit contact | partial | Contacts sheet: list with status, add by phone, delete; editing a contact's name is not there yet | S | M6 |
| New message / compose (pick a user) | done | ⌘N sheet: recent chats, contacts, username search | | |
| Edit own profile: name, bio, username, photo, birthday | partial | Name, username and bio in Settings; photo and birthday missing | M | M6 |
| Multiple accounts and switching | done | Up to 3 accounts in Settings, Account: switch, add, log out per account. Only the open account runs (one TDLib client; the others get no updates or notifications until opened); a switch restarts the session on the chosen slot. Layout is per account, preferences shared. Palette commands `app.account.<n>` | L | M6 |
| Log out | done | Settings, My profile, Log out | | |

### Settings

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Settings window shell in macOS System Settings style | done | Pages are descriptors in `settingsSections` | | |
| Notifications and sounds: per-type, badge, preview, sound | partial | Global switches, preview, sound and badge done (`NotificationsPage`); per-type scopes (private, groups, channels) and tones missing | S | M1 |
| Active sessions and terminate | partial | List, terminate one or all others; no auto-terminate period | S | M1 |
| Privacy and security: last seen, phone, photo, calls, forwards, groups, blocked list | done | Nine settings with Everybody / My contacts / Nobody and always / never lists, finding by phone, blocked list with block and unblock ([privacy_settings_controller.dart](../packages/core/lib/src/privacy_settings_controller.dart)); exceptions add people from the contacts only, groups already in a list are kept and can be removed | | |
| Two-step verification setup | done | Set, change and remove the password with a hint, recovery email with its code (resend, cancel, auto-submit at its length); a forgotten password is recovered by an email code, or reset after Telegram's wait without one (cancellable) | | |
| Passcode lock and Touch ID | partial | Passcode lock: salted PBKDF2 hash in the keychain, locked at launch, auto-lock after 1, 5, 15 or 60 minutes away, ⌘L, blurred lock screen, growing waits after five wrong tries, no message text in notifications while locked, log out when forgotten; no Touch ID | S | M7 |
| Delete account if away for 1, 3, 6 or 12 months | done | Privacy and security, Delete my account | | |
| Data and storage: cache usage, clear, limits, network usage | partial | Usage by kind, clear by kind, download folder; auto-download switches are stored but not yet applied; no limits or network usage | M | M7 |
| Appearance: theme, accent, night mode schedule, chat background, text size | partial | Theme, accent, wallpaper on or off, message text size, reduce motion; no night schedule or custom backgrounds | M | M7 |
| Language: UI language picker, translation settings | partial | System, English or Russian in Settings, Language, applied at once; no translation settings or TDLib language packs | S | M7 |
| Stickers and emoji: packs, reorder, archived, suggest, large emoji | partial | Settings > Stickers and emoji: installed sets dragged to reorder, archive or remove from the context menu, archived and trending pages, add by link, a set sheet (`showStickerSetSheet`), the same for custom emoji; large emoji, loop stickers and animated emoji switches. Set thumbnails are still frames; video (WebM) stickers loop regardless of the switch; suggest-by-emoji, emoji suggestions and dynamic pack order wait for composer suggestions | S | M7 |
| Quick reaction choice | missing | | S | M7 |
| Proxy: SOCKS5, MTProto, list, share | partial | SOCKS5, HTTP and MTProto in Settings, Proxy: "Use proxy", ping per proxy, add, edit, remove, `tg://proxy` and `t.me/proxy` links, a Proxy button on the sign-in screens; no share link or QR. TDLib keeps proxies per account database, so a new account slot starts without them (mirroring them is for the accounts work) | S | M7 |
| Connection status in the window ("Connecting…") | done | `ConnectionMonitor`, capsule in the sidebar title bar | | |
| Keyboard shortcuts list | done | Settings, Keyboard shortcuts: every command by group with key caps, rebinding with a conflict check, restore one or all; kept in preferences.json and applied live to the window, the palette and the shell | | |
| Auto-delete messages default | missing | | S | M7 |
| Settings search | partial | Filters the source list in both languages; no search inside pages | S | M7 |
| Ask a question, FAQ, about | missing | | S | M7 |

### Notifications and system integration

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Desktop notifications with reply and mark read | done | `NotificationController` on TDLib notification groups; macOS only, banners hidden while the window is in front | | |
| Dock badge with unread count | done | Unmuted chats by default; muted chats and message count are options | | |
| Notification sounds | partial | System default sound; Telegram tones and custom sounds missing | S | M1 |
| Menu bar and dock menu items | partial | Traffic lights done | S | M7 |
| Share extension, Spotlight, Focus filters | missing | macOS-only niceties | M | M9 |
| Auto update | missing | Sparkle or release-please assets | M | M8 |

### Calls

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| 1:1 audio and video calls | missing | Research done, `packages/calls` scaffold | L | M8 |
| Screen sharing | missing | | L | M8 |
| Call history | missing | `RecentCallsViewController` | S | M8 |
| Group calls and live streams | missing | | L | M9 |
| Call settings: devices, push-to-talk | missing | | M | M8 |

### Telegram platform

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Stories: view, react, reply, post, stealth mode | missing | `Story*` controllers | L | M9 |
| Premium: subscribe screen, limits, emoji status, profile colour | missing | `PremiumBoardingController` | L | M9 |
| Bots: start, menu button, inline keyboards, callback answers | missing | | M | M2 |
| Mini apps (web apps) | missing | `WebappBrowser`, needs a webview | L | M9 |
| Payments and invoices | missing | `PaymentsCheckoutController` | L | M9 |
| Stars: balance, paid media, paid reactions, subscriptions | missing | | L | M9 |
| Gifts and collectible gifts | partial | Service messages render | M | M9 |
| Instant View | missing | `InstantPage*` | L | M9 |
| Telegram Business: hours, location, quick replies, greeting/away, chatbots, links | missing | `Business*` | L | M9 |
| Monoforums (channel direct messages) | missing | | M | M9 |
| Telegram Passport | missing | | M | M9 |
| Games | missing | | S | M9 |
| Fact checks and verification badges | missing | | S | M9 |

## Mollygram on top of the official client

These are not parity items; they are tracked in their own docs.

| Feature | Status | Doc |
|---|---|---|
| Tabs, split view, ⌘K palette, layout restore | done | [packages/shell](../packages/shell) |
| JS plugin sandbox with manifest permissions (M5) | partial | [plugins.md](plugins.md) |
| Ghost mode: no read receipts, typing, online or played marks; per-chat silent read API (M3) | done | [privacy_guard.dart](../packages/core/lib/src/privacy_guard.dart) |
| Saved deleted messages, edit history (M3) | partial: kept in the encrypted store; the chat does not show them yet | [privacy-store.md](privacy-store.md) |
| 640×640 circles, uncompressed media by default (M4) | partial | [packages/media](../packages/media) |
