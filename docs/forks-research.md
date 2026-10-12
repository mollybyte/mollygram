# What to take from Telegram forks

A review of AyuGram, Kotatogram, Forkgram, Materialgram, 64Gram, Nagram/Nekogram, Octogram, Swiftgram and Unigram. Based on their READMEs as of 2026-10-12; items that could not be verified are marked "?". Cross-checked against the plan and the parity table (stages 2–8).

## Licenses

Mollygram is distributed under GPL-3.0. We do not copy fork code; we take only ideas and user-facing behavior, so there is no licensing issue. If we ever need to reuse code, keep in mind:

- GPL-3.0 compatible: tdesktop and its forks (AyuGram Desktop?, 64Gram, Materialgram, Forkgram?, Kotatogram?), Nagram, Unigram.
- GPL-2.0-only (Nekogram, Octogram, AyuGram4A, the Telegram macOS client) is not directly compatible with GPL-3.0.
- Trademarks: the Telegram name and logo cannot be used, and Nagram and several others require forks to be renamed. Our own `api_id` is mandatory, as planned.

## Feature list

Effort: S up to a week, M 1–3 weeks, L more.

| # | Feature | Found in | Why we want it | Effort | Stage |
|---|---------|----------|----------------|--------|-------|
| 1 | Ghost mode: don't send read receipts, "typing", "online" | AyuGram | The main privacy item, already in the plan | M | 5 |
| 2 | Reading without marking as read | AyuGram | Part of ghost mode, a separate per-chat toggle | S | 5 |
| 3 | Keeping deleted messages, marked as deleted | AyuGram | In the plan, own database | M | 5 |
| 4 | Edit history | AyuGram | In the plan; needs "edited/deleted" marks with a configurable style | S | 5 |
| 5 | Forwarding without the author and to several chats at once | Kotatogram, Forkgram, Cherrygram? | A small everyday feature missing from the official client | S | 3 |
| 6 | Sending and forwarding files uncompressed, photo quality and voice bitrate settings | Materialgram, Nekogram? | Matches our priority on attachment quality | M | 6 |
| 7 | Local chat folders | Kotatogram | Folders with no limit and no server; fits the workspace model | M | 4 |
| 8 | Message filters (hide ads, spam, by keyword) | AyuGram4A | A good first built-in plugin on the `message.render` hook | M | 7 |
| 9 | Inline message translation | AyuGram, Swiftgram, Nagram | A Premium feature in the official client, free for us via a plugin | M | 7 |
| 10 | Hiding the phone number in the profile, settings and header | Materialgram | Small, helps with screenshots, nearly free | S | 5 |
| 11 | Streamer mode: hide sensitive data while screen sharing | AyuGram Desktop | Complements privacy and the command palette | S | 5 |
| 12 | Choice of UI font and size, compact chat list | AyuGram, Kotatogram | Part of appearance settings; our design remains the default | S | 3 |
| 13 | Recent chats, "jump to first message", search for selected text from the context menu | Forkgram | Quick commands in the action registry, shown in the ⌘K palette | S | 4 |
| 14 | "Delete for everyone" by default, bulk deletion of more than 100 messages | Forkgram, Materialgram (experimental) | Convenience; bulk deletion needs careful handling of API limits | S | 3 |
| 15 | Noise suppression and voice enhancement while recording | Nagram | Fits into video and voice message recording | L | 6 |
| 16 | Plugin catalog and catalog bot | exteraGram? | Distribution idea: a plugin catalog with manifests and permissions; we do not adopt compatibility | M | 7 |
| 17 | Custom text replacements | Kotatogram | A simple setting, useful in the composer | S | 3 |
| 18 | Syncing saved deleted messages, edit history and state across devices (AyuSync) | AyuGram4A | Decided: we build it. Needs a server or self-hosting, client-side encryption | L | after release |

## Risky, but we take them

Project owner's decision: we take them. All of them are client-side, each behind its own toggle in settings, off by default, with an explanation of the risk.

| # | Feature | Found in | Note | Effort | Stage |
|---|---------|----------|------|--------|-------|
| 19 | Local Premium: shows the Premium UI on the client | AyuGram | Server-side features (limits, speed, translation) will not work; the settings say so | S | 5 |
| 20 | Screenshots in secret chats | AyuGram4A | The other party enabled protection on purpose; we show a warning | S | 5 |
| 21 | "Expire" button for TTL photos and videos, without emulator detection | AyuGram4A | Bypasses client restrictions; emulator detection is irrelevant on desktop | S | 5 |

## Not taking

- **exteraGram plugin compatibility**: decided earlier.

## ToS risks

Not verified with Telegram directly; assessed based on fork practice. Items 19–21 are the riskiest: Telegram may restrict the account or the api_id, and these features mislead the other party. Ghost mode, keeping deleted messages and hiding read receipts may be seen as interfering with expected behavior, but large forks with their own `api_id` ship them. All of this is done at the client level without changing the protocol. Recommendation: state plainly in the README that these are client-side features, and provide a single "safe mode" toggle.

## Decisions

1. Saved deleted messages are synced across devices (item 18), via a server or self-hosting, with data encrypted on the client.
2. Local Premium and protection bypasses are taken (items 19–21), behind toggles that are off by default.
3. Filters and translation are built as our own built-in plugins (items 8, 9).
