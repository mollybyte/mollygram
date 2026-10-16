import 'package:flutter/material.dart';

/// Color tokens from design/Main.dc.html (the `.app` and `.app.dark` rules).
///
/// Read them with `MgColors.of(context)`; they are installed as a
/// [ThemeExtension] by `buildMgTheme`.
@immutable
class MgColors extends ThemeExtension<MgColors> {
  const MgColors({
    required this.brightness,
    required this.fg,
    required this.fg2,
    required this.accent,
    required this.onAccent,
    required this.onAccentSecondary,
    required this.separator,
    required this.windowBackground,
    required this.bubbleIn,
    required this.bubbleOut,
    required this.bubbleShadow,
    required this.field,
    required this.hover,
    required this.avatarTop,
    required this.avatarBottom,
    required this.muted,
    required this.mediaPill,
    required this.datePill,
    required this.glass,
    required this.glassSolid,
    required this.rim,
    required this.highlight,
    required this.lowlight,
    required this.glow,
    required this.shadow,
    required this.wallpaperBase,
    required this.wallpaper,
    required this.frame,
    required this.card,
    this.selection,
  });

  final Brightness brightness;

  /// Primary text.
  final Color fg;

  /// Secondary text: subtitles, times, placeholders, idle icons.
  final Color fg2;

  /// Icons at rest: the secondary text's grey, one tone for both, as in
  /// TelegramSwift.
  Color get icon => fg2;

  /// [color] made opaque over the matte base of [glassSolid]. The blurred
  /// theme's frame and card are translucent so the desktop shows through
  /// the main surfaces; panels, dialogs and the settings window use this to
  /// stay readable and matte instead of showing the desktop sharply.
  Color solid(Color color) => color.a >= 0.99
      ? color
      : Color.alphaBlend(color, glassSolid.withValues(alpha: 1));

  /// The composer's resting icons and its placeholder: lighter than the
  /// secondary text in the light theme, so they don't read as typed text.
  Color get quiet => isDark ? fg2 : muted;

  /// The single accent: selection, unread badges, send button, links.
  final Color accent;

  /// Text and icons on top of [accent].
  final Color onAccent;

  /// Secondary text on top of [accent] (rgba(255,255,255,.82)).
  final Color onAccentSecondary;
  final Color separator;

  /// Plain window background for screens without the wallpaper, such as
  /// sign-in.
  final Color windowBackground;

  /// Incoming message bubble. Also the glass fill when transparency is
  /// reduced, as in the mockup.
  final Color bubbleIn;

  /// Outgoing message bubble.
  final Color bubbleOut;

  /// The 0 1px 1px bubble shadow; null in the dark theme.
  final Color? bubbleShadow;

  /// Fill of inputs, the selected folder tab and toggled icon buttons.
  final Color field;
  final Color hover;

  /// Top and bottom of the gray monogram avatar gradient.
  final Color avatarTop;
  final Color avatarBottom;

  /// Badge of a muted chat.
  final Color muted;

  /// The dark pill with the time over photos and video messages.
  final Color mediaPill;

  /// The date separator pill over the wallpaper.
  final Color datePill;

  /// Glass fill (rgba .42) when blur is on.
  final Color glass;

  /// Glass fill when blur is off (reduced transparency).
  final Color glassSolid;

  /// The 1 px light rim.
  final Color rim;

  /// Inset top highlight (inset 0 1px 0).
  final Color highlight;

  /// Inset bottom line (inset 0 -1px 0).
  final Color lowlight;

  /// Inner glow (inset 0 0 18px).
  final Color glow;

  /// The 0 12px 34px drop shadow under glass.
  final Color shadow;

  /// Base color under the wallpaper gradient.
  final Color wallpaperBase;

  /// The four points of the Telegram gradient wallpaper, in mockup order:
  /// top left, top right, bottom right, bottom left.
  final List<Color> wallpaper;

  /// The window frame: the tinted surface the sidebar sits on and the chat
  /// cards float over.
  final Color frame;

  /// The chat card: the solid surface of a conversation pane.
  final Color card;

  /// The fill of the selected chat row, when it differs from [accent] (a
  /// light accent of the dark theme needs a deeper fill under white text).
  final Color? selection;

  /// The fill of the selected chat row.
  Color get selected => selection ?? accent;

  bool get isDark => brightness == Brightness.dark;

  /// The "Draft:" lead in the chat list, the system red of both themes.
  static const draftRed = Color(0xFFFF453A);

  static const light = MgColors(
    brightness: Brightness.light,
    fg: Color(0xFF1D1D1F),
    fg2: Color(0xFF56565B),
    accent: Color(0xFF0071E3),
    onAccent: Color(0xFFFFFFFF),
    onAccentSecondary: Color(0xD1FFFFFF),
    separator: Color(0x14000000),
    windowBackground: Color(0xFFFFFFFF),
    bubbleIn: Color(0xFFFFFFFF),
    bubbleOut: Color(0xFFEFFDDE),
    bubbleShadow: Color(0x12000000),
    field: Color(0x0E000000),
    hover: Color(0x0D000000),
    avatarTop: Color(0xFFA9ADB6),
    avatarBottom: Color(0xFF878B94),
    muted: Color(0xFF737378),
    mediaPill: Color(0x59000000),
    datePill: Color(0x8C000000),
    glass: Color(0x6BFFFFFF),
    glassSolid: Color(0xF0F7F7F9),
    rim: Color(0x99FFFFFF),
    highlight: Color(0xF2FFFFFF),
    lowlight: Color(0x4DFFFFFF),
    glow: Color(0x59FFFFFF),
    shadow: Color(0x291E3214),
    wallpaperBase: Color(0xFFB5C99E),
    wallpaper: [
      Color(0xFFDBDDBB),
      Color(0xFF6BA587),
      Color(0xFFD5D88D),
      Color(0xFF88B884),
    ],
    frame: Color(0xFFE6E8EC),
    card: Color(0xFFFFFFFF),
  );

  static const dark = MgColors(
    brightness: Brightness.dark,
    fg: Color(0xFFF5F5F7),
    fg2: Color(0xFFAEAEB3),
    accent: Color(0xFF0A84FF),
    onAccent: Color(0xFFFFFFFF),
    onAccentSecondary: Color(0xD1FFFFFF),
    separator: Color(0x17FFFFFF),
    windowBackground: Color(0xFF1C1C1E),
    bubbleIn: Color(0xFF2A2A2D),
    bubbleOut: Color(0xFF2B5278),
    bubbleShadow: null,
    field: Color(0x12FFFFFF),
    hover: Color(0x0FFFFFFF),
    avatarTop: Color(0xFF71757E),
    avatarBottom: Color(0xFF565A62),
    muted: Color(0xFF98989D),
    mediaPill: Color(0x59000000),
    datePill: Color(0x2E000000),
    glass: Color(0x6B1C1E22),
    glassSolid: Color(0xF0222428),
    rim: Color(0x24FFFFFF),
    highlight: Color(0x38FFFFFF),
    lowlight: Color(0x0DFFFFFF),
    glow: Color(0x0AFFFFFF),
    shadow: Color(0x73000000),
    wallpaperBase: Color(0xFF1A2A35),
    wallpaper: [
      Color(0xFF2D4A5C),
      Color(0xFF1C3442),
      Color(0xFF3B5465),
      Color(0xFF203845),
    ],
    frame: Color(0xFF1C1D20),
    card: Color(0xFF26272B),
  );

  /// The tokens of the nearest theme. Falls back to [light] when the theme
  /// was not built with `buildMgTheme`.
  static MgColors of(BuildContext context) =>
      Theme.of(context).extension<MgColors>() ?? light;

  static const Object _keep = Object();

  /// Returns a copy with the given tokens replaced. Pass
  /// `bubbleShadow: null` to remove the bubble shadow.
  @override
  MgColors copyWith({
    Brightness? brightness,
    Color? fg,
    Color? fg2,
    Color? accent,
    Color? onAccent,
    Color? onAccentSecondary,
    Color? separator,
    Color? windowBackground,
    Color? bubbleIn,
    Color? bubbleOut,
    Object? bubbleShadow = _keep,
    Color? field,
    Color? hover,
    Color? avatarTop,
    Color? avatarBottom,
    Color? muted,
    Color? mediaPill,
    Color? datePill,
    Color? glass,
    Color? glassSolid,
    Color? rim,
    Color? highlight,
    Color? lowlight,
    Color? glow,
    Color? shadow,
    Color? wallpaperBase,
    List<Color>? wallpaper,
    Color? frame,
    Color? card,
    Object? selection = _keep,
  }) {
    return MgColors(
      brightness: brightness ?? this.brightness,
      fg: fg ?? this.fg,
      fg2: fg2 ?? this.fg2,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      onAccentSecondary: onAccentSecondary ?? this.onAccentSecondary,
      separator: separator ?? this.separator,
      windowBackground: windowBackground ?? this.windowBackground,
      bubbleIn: bubbleIn ?? this.bubbleIn,
      bubbleOut: bubbleOut ?? this.bubbleOut,
      bubbleShadow: identical(bubbleShadow, _keep)
          ? this.bubbleShadow
          : bubbleShadow as Color?,
      field: field ?? this.field,
      hover: hover ?? this.hover,
      avatarTop: avatarTop ?? this.avatarTop,
      avatarBottom: avatarBottom ?? this.avatarBottom,
      muted: muted ?? this.muted,
      mediaPill: mediaPill ?? this.mediaPill,
      datePill: datePill ?? this.datePill,
      glass: glass ?? this.glass,
      glassSolid: glassSolid ?? this.glassSolid,
      rim: rim ?? this.rim,
      highlight: highlight ?? this.highlight,
      lowlight: lowlight ?? this.lowlight,
      glow: glow ?? this.glow,
      shadow: shadow ?? this.shadow,
      wallpaperBase: wallpaperBase ?? this.wallpaperBase,
      wallpaper: wallpaper ?? this.wallpaper,
      frame: frame ?? this.frame,
      card: card ?? this.card,
      selection: identical(selection, _keep)
          ? this.selection
          : selection as Color?,
    );
  }

  @override
  MgColors lerp(MgColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return MgColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      fg: c(fg, other.fg),
      fg2: c(fg2, other.fg2),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      onAccentSecondary: c(onAccentSecondary, other.onAccentSecondary),
      separator: c(separator, other.separator),
      windowBackground: c(windowBackground, other.windowBackground),
      bubbleIn: c(bubbleIn, other.bubbleIn),
      bubbleOut: c(bubbleOut, other.bubbleOut),
      bubbleShadow: Color.lerp(bubbleShadow, other.bubbleShadow, t),
      field: c(field, other.field),
      hover: c(hover, other.hover),
      avatarTop: c(avatarTop, other.avatarTop),
      avatarBottom: c(avatarBottom, other.avatarBottom),
      muted: c(muted, other.muted),
      mediaPill: c(mediaPill, other.mediaPill),
      datePill: c(datePill, other.datePill),
      glass: c(glass, other.glass),
      glassSolid: c(glassSolid, other.glassSolid),
      rim: c(rim, other.rim),
      highlight: c(highlight, other.highlight),
      lowlight: c(lowlight, other.lowlight),
      glow: c(glow, other.glow),
      shadow: c(shadow, other.shadow),
      wallpaperBase: c(wallpaperBase, other.wallpaperBase),
      wallpaper: [
        for (var i = 0; i < wallpaper.length; i++)
          c(wallpaper[i], other.wallpaper[i]),
      ],
      frame: c(frame, other.frame),
      card: c(card, other.card),
      // Lerping towards a missing selection would fade it out; the accent
      // stands in for it.
      selection: selection == null && other.selection == null
          ? null
          : c(selected, other.selected),
    );
  }
}
