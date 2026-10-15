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
| Chat list context menu: pin, mute, archive, mark read/unread, clear, delete, leave | done | `chat_menu.dart`; mute for 1 h, 8 h, 3 days or forever. Missing: mute until a date, sound picker, add to folder, preview | | |
| Archive folder entry and archive view | done | Archive row on top of All, "Mark all as read". Missing: collapsing or hiding the row | | |
| Unread mention and reaction badges in the list | done | Plus marked-as-unread, muted gray badge, pin icon, secret chat lock | | |
| Typing and online dot in the list | done | `PresenceController` | | |
| Draft preview in the list ("Draft: …") | partial | `UpdateChatDraftMessage` is stored, not shown | S | M1 |
| Pinned chats order with drag | missing | `SetPinnedChats` | S | M6 |
| Folder editor: create, edit, delete, reorder, include/exclude, recommended | done | Settings > Chat folders: drag reorder, editor sheet with icon, chat types and a chat picker, delete with chats to leave, recommended folders; `ChatFoldersController` in core. No pinning inside a folder or "All chats" position yet | | M6 |
| Folder sidebar (vertical tabs) and folder icons | missing | Official offers left-side folders | M | M7 |
| Shared folders (chat folder invite links) | missing | `CreateChatFolderInviteLink` | M | M9 |
| Saved Messages as a list of sub-chats | done | The list button in the Saved Messages capsule shows the chats the saved messages came from (`loadSavedMessagesTopics`, kept live from `updateSavedMessagesTopic`): own notes, a hidden author and one row per chat, pinned first, with the last message and time; one opens in place with its history (`getSavedMessagesTopicHistory`) and a composer, and its menu pins or deletes it. Tags (`getSavedMessagesTags`, live from `updateSavedMessagesTags`) sit in a bar under the header: a chip per tag with its emoji, name and count; a click shows the messages carrying it (`searchSavedMessages`), the chip again shows everything, a right click names the tag (`setSavedMessagesTagLabel`) | M | M2 |
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
| Header status: online, last seen, members, typing | done | `chat_status.dart`; online count shows for open groups | | |
| Join and mute buttons for channels and groups you are not in | done | Join in place of the composer; Mute and Unmute in channels you only read | | |
| Open `t.me` and `tg://` links, usernames, hashtags, bot commands | done | `links/`: links, mentions and mentions by name, invites, `tg://user?id=`, `t.me/s/` previews, message links jump to the message; hashtags open the ⌘K message search, bot commands are sent to the chat | | |
| Link previews in messages | done | Site name, title, description and picture, large or as a thumbnail, opening the link; the draft's preview above the composer can go above the text or be dropped | M | M1 |
| Text selection across messages | done | Mouse selection over the timeline, copy with the shortcut | M | M2 |
| Multi-select mode: forward, delete, copy several | done | Select from the menu, click rows, bar in place of the composer; no shift-click range yet | M | M2 |
| Forum topics: topic list, topic chat, create and close topics | partial | A forum opens as its list of topics in the timeline's place (pinned first, icon or custom emoji, last message, time, unread badge, closed ones muted), kept live from `updateForumTopic*`; a topic opens in place with a back capsule and a composer, through `getForumTopicHistory` and `messageTopicForum`. A "New topic" row for those who may, and a topic's menu pins, closes or reopens, renames and deletes it (`createForumTopic`, `editForumTopic`, `toggleForumTopicIsClosed`, `toggleForumTopicIsPinned`, `deleteForumTopic`). The topic sheet picks the icon: one of the six colour tiles with the name's initial, or a custom emoji from `getForumTopicDefaultIcons`; editing swaps the emoji (`editForumTopic`) | L | M2 |
| Channel comments (discussion thread) | partial | The comments row under a post opens the thread in place of the timeline, with a back capsule, live updates and a composer for text; a comment's menu replies to it, quotes it, edits or forwards it; an accent dot marks posts with unread comments; files dropped, pasted or attached while the comments are open go into the thread with the comment draft as caption | M | M2 |
| Reply threads in groups | done | A group message with replies shows "N replies" with the repliers' avatars; it opens the thread in place of the timeline, with a Reply composer, like the comments under a post | M | M2 |
| Secret chats | partial | Start from New message (Secret chat) or a person's info panel; state pending, ready or closed (`SecretChatsController`); encryption key sheet with the 12×12 key picture and hex, as the official apps draw them; self-destruct timer (off, 1 s to 1 week) and Close in the palette for the focused secret chat; closed bar with Delete chat. The chat header capsule, chat list row and header menu consume `secretChatProvider`, `SecretChatLock` and the sheets from `secret/secret_chat.dart`, wired by the chat and sidebar work | L | M6 |
| Secret chat screenshot blocking | done | The window is kept out of screenshots and screen recordings while any pane of the active tab shows a secret chat (macOS `sharingType = .none`, best effort on macOS 15 and later, where some capture APIs ignore it; Windows and Linux not yet). Privacy extras, "Allow screenshots in secret chats" (off, risky) skips it | S | M3 |
| Spoilers, custom emoji in text | done | `concealed.dart` covers spoilers; custom emoji are drawn as their stickers (`GetCustomEmojiStickers`, one batch per frame), still, at 1.3× the text size, with the emoji text as the fallback | M | M2 |
| Polls and quizzes: vote, results | done | Vote with radios or checkboxes and a Vote button, Retract vote, live results with bars, quiz answers coloured with the explanation, Stop poll from the menu; a public poll shows its latest voters and lists who voted for an option on a click | S | M2 |
| Checklists (todo messages) | done | Title, tasks with accent boxes, struck-through done tasks with the avatar of who did them, a done count; a click marks a task done or not done when allowed | S | M9 |
| Dice and slot animations | done | A dice message draws the sticker of its thrown value (the rolling one until the server picks it); the slot machine stacks its background, reels and lever | S | M9 |
| Live location view | partial | Locations, venues and live locations show a map from `getMapThumbnailFile` with a pin (the sharer's avatar for a live one), the venue's name and address or the time left; a click opens Maps. No live map of several sharers | M | M2 |
| Auto-translate and "Translate" in the menu | partial | A bar under the chat header offers "Translate to English" when the chat is in another language (detected on the device); a click translates the whole chat in place, a few messages at a time with Telegram's free per-message translation, and the bar becomes "Translated from Russian · Show original". The three dots choose the language, skip a language or hide the bar. No "Translate" item in the message menu or on selected text yet | M | M5 |
| Voice message transcription | done | A button next to a voice message's time asks TDLib (`RecognizeSpeech`, Premium with free trials) and shows the transcript under the waveform, partial text while it runs, a quiet note on failure; a second click folds it | S | M9 |
| Message effects and reaction animations | missing | | M | M9 |
| Sponsored messages in channels | done | A channel's sponsored message (`getChatSponsoredMessages`) sits under the timeline as a flat card: sponsor photo and title, a "Sponsored" tag that explains itself, the text and the sponsor's button; shown once per visit, counted with `viewMessages` and `clickChatSponsoredMessage`. Required by Telegram's API terms | S | M2 |

### Message actions

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Reply, edit, delete (for me / for everyone), forward, copy text, copy link | done | #30 | | |
| Quick reactions and toggling reactions | done | #30 | | |
| Full reaction picker (all emoji, custom reactions) | done | Chevron in the reaction bar opens a grid of every reaction TDLib offers; custom emoji reactions are drawn as their stickers in the bar, the grid and the chips under a message | S | M2 |
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
| Sticker panel, recent and favourite stickers, sticker search | done | Recent, favourites, installed sets, and a search field over them that finds stickers by emoji or word in the user's language and English (`SearchStickers`); sets are managed in Settings > Stickers and emoji | S | M1 |
| GIF panel and GIF search | done | A GIFs tab in the emoji panel lists the saved GIFs (`GetSavedAnimations`), each playing under the pointer, and sends one with a click; GIF search is `@gif cats` in the composer, through inline bots | M | M2 |
| Emoji and sticker suggestions while typing | done | `:word` offers Telegram's emoji keywords in the composer popup; a draft that is one emoji shows a strip of matching stickers above the composer | M | M2 |
| Rich text formatting: bold, italic, code, link, spoiler, quote; Markdown shortcuts | done | `RichTextEditingController` in ui_kit: ⌘B, ⌘I, ⌘U, ⌘⇧X, ⌘⇧M, ⌘⇧P, ⌘⇧., ⌘K, context menu; Markdown converted on send. Captions of files are still plain | | |
| Mentions autocomplete (@) | done | `MentionSearch` with `ChatMembersFilterMention`; no `:` emoji shortcodes yet | | |
| Bot command autocomplete (/) and bot keyboards | partial | A / or the bot's menu button offers the commands the chat's bots announce and sends the pick; inline keyboards under messages (links, callbacks with the bot's answer as a toast, copy text, user links, switch-to-inline here or in a chosen chat) and the bot's reply keyboard above the composer with a toggle; its buttons send text, share the phone number after a confirmation, make a poll in the mode asked for, pick a user or a chat to share (`shareUsersWithBot`, `shareChatWithBot`) or send a place from the location sheet; web app requests pending | M | M2 |
| Inline bots (@gif, @vid) | done | `@bot query` in the composer shows the bot's results over it (`GetInlineQueryResults`): a grid for GIFs, photos, videos and stickers that play under the pointer, rows for articles and the rest, more pages as the grid scrolls; a click sends the result via the bot | M | M9 |
| Voice message recording | done | Hold, lock, cancel; Opus in Ogg via AudioToolbox on macOS | M | M1 |
| Video message (circle) recording | partial | Hold, lock, cancel, 60 s limit; 640×640 H.264 via AVFoundation on macOS. Switch between built-in, external and Continuity cameras while recording (the last one is remembered). No preview before sending | L | M4 |
| Silent send and scheduled messages, scheduled list | done | Right click or long press on Send: without sound, at a day and time or, in a private chat with a person, when they come online; a clock in the composer opens the scheduled list with Send now, Reschedule and Delete; a right click on Send in the attachment preview offers the same | S | M2 |
| Send as (channel identity) | done | Where TDLib sets the chat's `message_sender_id`, the composer shows the identity's avatar before the attach button; a click lists the account and the user's channels (`GetChatAvailableMessageSenders`), Premium-only ones greyed, and picks one with `SetChatMessageSender` | S | M6 |
| Polls and quizzes creation | done | Attach menu > Poll… in groups and channels: question, up to ten options, anonymous voting, multiple answers, quiz mode with the right answer and an explanation | M | M2 |
| Location and venue sending | partial | Location… under the attach button: a sheet with a map to drag and zoom (`getMapThumbnailFile`) around the pin, a field that takes coordinates or a maps link, and venues around the pin from the venue bot (`venue_search_bot_username`, `getInlineQueryResults`); a row sends the point (`inputMessageLocation`) or the venue (`inputMessageVenue`). No current position yet (CoreLocation), no live location | M | M2 |
| Contact sending | done | Contact… under the attach button opens a searchable list of contacts; the message shows the monogram, name and number and opens the person | S | M2 |
| Send preview: caption, send as files, albums | done | #31 | | |
| Send preview: spoiler, self-destruct timer, compression choice | partial | Hide with a spoiler, Send as files and, in private chats, a self-destruct timer (view once, 3 s to 1 min) in the preview; a quality choice pending | S | M2 |
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
| Photos, videos, GIFs, stickers (WebP, TGS, WebM) in chat | done | #29; a click on a sticker opens its set with Add or Remove, as in the official client | | |
| Voice messages playback with waveform | done | | | |
| Video circles playback at 120 fps | done | `packages/media` | | |
| Files and music: download, open, cancel | done | | | |
| Fullscreen media viewer on a dimmed backdrop, open and close animation | done | Viewer PR | | |
| Viewer: arrows and swipe between the chat's photos and videos, thumbnail strip | done | Arrows and keys over `SearchChatMessages`; a thumbnail strip under the page, centered on the one on screen, jumps to any of them; a two-finger swipe turns the page unless the photo is zoomed in | S | M2 |
| Viewer: zoom (pinch, scroll, double click) and pan, rotate | done | Zoom and pan; a Rotate button and R turn photos and videos by quarters, shrinking a sideways page to fit | S | M2 |
| Viewer: video scrubbing, loop, playback speed, volume, fullscreen | partial | Viewer PR: scrubbing, loop, speed, mute; plays once downloaded, no streaming | S | M2 |
| Viewer: GIFs and video stickers looped | done | GIFs loop in the viewer; a video sticker, as in the official apps, opens its sticker set rather than the viewer | | |
| Viewer: save, copy, forward, delete, show in chat, keyboard shortcuts | done | Save, copy, forward, show in chat (closes the viewer at the message), delete (asks over the viewer, Delete or Backspace key); Esc, arrows, Space, ⌘S, ⌘C | S | M2 |
| Global audio player with playlist and header bar | done | A glass capsule at the right of the chat header while a voice message or music file plays: play/pause, sender or title, time, speed, close; its title shows the message, opening its chat when needed; a finished track goes on to the next one; a list button opens the chat's voice messages or music as a playlist, the playing one in the accent, a click plays another | M | M2 |
| Picture-in-picture for video and circles | missing | `PIPVideoWindow` | M | M4 |
| Voice playback speed and continuous play | done | Speed 1×, 1.5×, 2× and waveform scrubbing; a finished voice message goes on to the next newer one of the chat (music to the next music file), downloading it first | S | M1 |
| Downloads manager (list, pause, show in Finder) | done | `DownloadsController` in core over TDLib's downloads list (`addFileToDownloads`, `updateFileDownload*`): a bar above the chat list while something downloads or is paused (ring, count, bytes), a sheet (⌘⇧J, palette) with active first, pause/resume per file and for all, Quick Look, Show in Finder, Show in chat, remove, clear finished. Clicked downloads in chats (files, audio, Save as, Save to Downloads) go through `DownloadsController.add`, so they appear on the list | | M7 |
| Autodownload rules | partial | The Data and storage switches reach `FileController.autoDownloadKinds`; photos, GIFs, video messages and link preview pictures in the timeline download through `FileController.autoDownload(kind:)`, and a kind that is off shows its preview with a download button. No per-chat-type rules or size limits yet | S | M7 |
| Quick Look for documents | done | Quick Look in the menu of a downloaded file on macOS (`qlmanage -p`) | S | M2 |

### Search

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Chat search in the sidebar and ⌘K palette | done | `chat_search.dart`, #27 | | |
| Global message search | done | `SearchMessages` in the ⌘K palette (# prefix or any query); a hit opens its chat, in the chosen pane or tab, scrolled to the message | M | M2 |
| Search inside a chat, by sender, by date | done | ⌘F capsule with result arrows (`chat_search/`), a calendar button that jumps to a day and, in groups, a member picker that narrows the results to one sender | S | M2 |
| Hashtag and cashtag search | done | A tapped hashtag or cashtag opens a results sheet with This chat, My messages and Public posts tabs (`searchChatMessages`, `searchMessages`, `searchPublicMessagesByTag`), paged as it scrolls; a row opens the message in its chat | | M2 |
| Search filters (media, links, files, voice) | done | The shared media tabs and, in ⌘F, a filter button whose menu narrows the results to media, files, links, voice or music, shown as a chip before the query | S | M2 |
| Recent searches and top peers | missing | | S | M2 |

### Profiles and info panels

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| User profile: photo, bio, username, phone, birthday, actions | done | `PeerInfoController` in core, inspector panel in `app/lib/src/profile` | | |
| Group and channel info: description, link, members count | done | First 50 members, most recently active first | | |
| Shared media tabs: media, files, links, voice, music, GIFs, groups in common | partial | `SharedMediaView` in the info panel: media, files, links, voice, music and GIFs (`searchChatMessages` by filter, GIFs in the grid and the viewer), and for a user the groups in common (`getGroupsInCommon`), each a row that opens the group | M | M2 |
| Members list with search | done | Info panel (`profile/`): owner and admins first, then online; search and Show more pages through `getSupergroupMembers` | | |
| Profile photo gallery | done | The big photo in the info panel opens the viewer with the profile's photos newest first (`getUserProfilePhotos`; for a group or channel its photo-change messages), the name and when each was set on top, arrows and thumbnails to page | S | M2 |
| Per-chat notifications and auto-delete timer | done | The info panel's Mute tile offers an hour, eight hours, two days or until turned back on (`setChatNotificationSettings`), Unmute when muted; an Auto-delete messages row shows the chat's timer and sets off, a day, a week or a month (`setChatMessageAutoDeleteTime`) for private chats and groups the user may edit | S | M1 |
| Block, report, share contact | done | Block and unblock, Report (the server's reasons through `reportChat`, as for a message) and Share contact (a chat picker, then the contact card) in the info panel | S | M6 |

### Groups, channels and admin tools

| Feature | Status | Notes | Size | M |
|---|---|---|---|---|
| Create group and channel | done | ⌘K New group (contacts, then a name and photo) and New channel (name, description, photo and an optional public link) | | |
| Edit title, photo, description, username, public/private | done | Edit sheet for title, description and photo; the owner's "Group type" row switches between private and public with the link checked as typed (`profile/chat_type_sheet.dart`) | | |
| Add, remove, ban members; admin rights and titles | done | Member context menu: make admin with a rights sheet and a title, edit or dismiss, restrict, remove; "Add members" picks contacts for an existing group or channel | | |
| Group permissions, slow mode | done | Permissions sheet with what every member may do and slow mode off to 1 hour (`profile/permissions_sheet.dart`) | | |
| Invite links: create, revoke, join requests | done | Primary link copy and revoke, additional links with expiry, limit and approval, editing a link; "Join requests" sheet with Approve and Dismiss, "Approve new members" switch | | |
| Leave a group or channel, delete it for everyone | done | Info panel rows with a confirmation; delete only for the owner | | |
| Linked discussion group | done | A channel picks one of the user's groups or unlinks it; a group shows its channel (`profile/discussion_sheet.dart`) | | |
| Allowed reactions, chat history for new members | done | Reactions sheet: all, some (emoji chips) or none; "Show history to new members" switch where Telegram allows it | | |
| Recent actions (admin log) | done | Recent actions sheet by day, filtered by administrator, every TDLib event in words (`profile/admin_log_sheet.dart`) | | |
| Enable topics in a group | done | "Topics" switch in the management rows | | |
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
| Data and storage: cache usage, clear, limits, network usage | partial | Usage by kind, clear by kind, download folder; auto-download switches apply to media in chats; no limits or network usage | M | M7 |
| Appearance: theme, accent, night mode schedule, chat background, text size | done | Theme, accent, dark theme by schedule (from/to half hours), chat background: five four-point gradients (classic, ocean, lavender, sand, graphite) with light and dark variants, plain, or a picture of your own with an optional blur; message text size; media corners (small/medium/large) and compact layout through `MgMetrics` in the theme; Dock icon (crimson, blue, graphite) through `NSApp.applicationIconImage`; reduce motion. No day/night colour themes beyond light and dark, no wallpaper patterns | | M7 |
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
| Bots: start, menu button, inline keyboards, callback answers | partial | Start in place of the composer in a fresh bot chat, / command popup, inline keyboards and callback answers; the menu button before the attach icon lists the commands or opens the bot's Web App in the browser, signed through `getWebAppUrl`; Web Apps inside the window pending | M | M2 |
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
| Saved deleted messages, edit history (M3) | done: kept in the encrypted store; a kept deleted message stays in the chat, dimmed and marked "deleted" with the time on hover, and an edited message's menu opens its earlier versions ("Edit history") while the switches are on | [privacy-store.md](privacy-store.md) |
| 640×640 circles, uncompressed media by default (M4) | partial | [packages/media](../packages/media) |
