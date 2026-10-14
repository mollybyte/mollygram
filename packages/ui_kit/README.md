# mollygram_ui_kit

The Mollygram design system in Flutter, ported from `design/*.dc.html` and the
`prototype/`.

- **Tokens**: `MgColors.light` / `MgColors.dark` (a `ThemeExtension`),
  `buildMgTheme`, the `MgType` scale and `mgTextStyle` (system font, 13 px).
- **Glass**: `Glass` and `GlassScope`. Glass is for the floating layer only:
  the sidebar island, the two chat header capsules, the composer and the
  command palette. Messages and rows stay solid. Wrap the window in one
  `GlassScope` so all panels share a single backdrop read; `blur: false` is
  the reduced transparency fallback.
- **Wallpaper**: the four-point Telegram gradient.
- **Sign-in**: `SignInPage`, `SignInHeader`, `QrFrame`, `SignInSteps`, `PhoneNumberField`, `MgUnderlineField`, `MgPrimaryButton`, `MgTextButton`. Plain window background, no wallpaper and no glass, as in the official Telegram apps.
- **Widgets**: `SidebarIsland`, `MgSearchField`, `FolderTabBar` / `FolderTab`,
  `ChatListTile`, `ChatHeaderBar` with `ChatTitleCapsule` and
  `ChatActionsCapsule`, `Composer`, `MessageBubble`, `TextMessageBubble`,
  `MessageMeta`, `DatePill`, `MediaPill`, `MonogramAvatar`, `UnreadBadge`,
  `MgIconButton`, `MgSendButton`, and the `MgIcons` set.

The kit has no strings of its own. Every label, tooltip and placeholder comes
from the app, which owns localization.

## Tests

`flutter test` runs widget tests and golden images (`test/goldens/`). Goldens
are rendered on Linux, like CI, and are skipped on other hosts. After an
intended visual change, update them on Linux:

```sh
flutter test --update-goldens
```
