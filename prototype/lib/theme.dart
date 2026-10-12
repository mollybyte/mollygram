import 'package:flutter/material.dart';

/// Цвета из макета design/Main.dc.html (переменные .app и .app.dark).
@immutable
class MgColors extends ThemeExtension<MgColors> {
  const MgColors({
    required this.dark,
    required this.fg,
    required this.fg2,
    required this.accent,
    required this.bubbleIn,
    required this.bubbleOut,
    required this.field,
    required this.hover,
    required this.av1,
    required this.av2,
    required this.muted,
    required this.glass,
    required this.glassSolid,
    required this.rim,
    required this.hi,
    required this.lo,
    required this.glow,
    required this.shadow,
    required this.bubbleShadow,
    required this.wallBase,
    required this.wall,
  });

  final bool dark;
  final Color fg;
  final Color fg2;
  final Color accent;
  final Color bubbleIn;
  final Color bubbleOut;
  final Color field;
  final Color hover;
  final Color av1;
  final Color av2;
  final Color muted;
  final Color glass;

  /// Заливка стекла, когда размытие выключено (как prefers-reduced-transparency).
  final Color glassSolid;
  final Color rim;
  final Color hi;
  final Color lo;
  final Color glow;
  final Color shadow;
  final Color? bubbleShadow;
  final Color wallBase;

  /// Четыре точки градиентных обоев Telegram, порядок как в макете.
  final List<Color> wall;

  static const light = MgColors(
    dark: false,
    fg: Color(0xFF1D1D1F),
    fg2: Color(0xFF56565B),
    accent: Color(0xFF0071E3),
    bubbleIn: Color(0xFFFFFFFF),
    bubbleOut: Color(0xFFEFFDDE),
    field: Color(0x0E000000),
    hover: Color(0x0D000000),
    av1: Color(0xFFA9ADB6),
    av2: Color(0xFF878B94),
    muted: Color(0xFFA1A1A6),
    glass: Color(0x6BFFFFFF),
    glassSolid: Color(0xF0F7F7F9),
    rim: Color(0x99FFFFFF),
    hi: Color(0xF2FFFFFF),
    lo: Color(0x4DFFFFFF),
    glow: Color(0x59FFFFFF),
    shadow: Color(0x291E3214),
    bubbleShadow: Color(0x12000000),
    wallBase: Color(0xFFB5C99E),
    wall: [
      Color(0xFFDBDDBB),
      Color(0xFF6BA587),
      Color(0xFFD5D88D),
      Color(0xFF88B884),
    ],
  );

  static const darkTheme = MgColors(
    dark: true,
    fg: Color(0xFFF5F5F7),
    fg2: Color(0xFFAEAEB3),
    accent: Color(0xFF0A84FF),
    bubbleIn: Color(0xFF2A2A2D),
    bubbleOut: Color(0xFF2B5278),
    field: Color(0x12FFFFFF),
    hover: Color(0x0FFFFFFF),
    av1: Color(0xFF71757E),
    av2: Color(0xFF565A62),
    muted: Color(0xFF636366),
    glass: Color(0x6B1C1E22),
    glassSolid: Color(0xF0222428),
    rim: Color(0x24FFFFFF),
    hi: Color(0x38FFFFFF),
    lo: Color(0x0DFFFFFF),
    glow: Color(0x0AFFFFFF),
    shadow: Color(0x73000000),
    bubbleShadow: null,
    wallBase: Color(0xFF1A2A35),
    wall: [
      Color(0xFF2D4A5C),
      Color(0xFF1C3442),
      Color(0xFF3B5465),
      Color(0xFF203845),
    ],
  );

  static MgColors of(BuildContext context) =>
      Theme.of(context).extension<MgColors>()!;

  @override
  MgColors copyWith() => this;

  @override
  MgColors lerp(MgColors? other, double t) => t < 0.5 ? this : other ?? this;
}

ThemeData buildTheme(MgColors c) {
  final base = ThemeData(
    brightness: c.dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: c.dark ? Brightness.dark : Brightness.light,
      primary: c.accent,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.28),
    ),
    extensions: [c],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.fg, displayColor: c.fg),
  );
}

/// Базовый стиль текста: системный шрифт, 13 px.
TextStyle mgText(MgColors c, {double size = 13, FontWeight? weight}) =>
    TextStyle(
      fontSize: size,
      height: 1.4,
      fontWeight: weight,
      color: c.fg,
      letterSpacing: 0,
    );
