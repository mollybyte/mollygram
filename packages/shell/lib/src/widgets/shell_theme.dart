import 'package:flutter/widgets.dart';

/// Colors the shell draws with, taken from the design mocks
/// (`design/Main.dc.html`, `design/Palette.dc.html`).
///
/// Kept local until `mollygram_ui_kit` ships its theme; the values match it.
@immutable
class ShellColors {
  const ShellColors({
    required this.fg,
    required this.fg2,
    required this.separator,
    required this.accent,
    required this.field,
    required this.hover,
    required this.paletteGlass,
    required this.rim,
    required this.highlight,
    required this.glow,
    required this.paletteShadow,
    required this.avatarTop,
    required this.avatarBottom,
  });

  static const light = ShellColors(
    fg: Color(0xFF1D1D1F),
    fg2: Color(0xFF56565B),
    separator: Color(0x14000000),
    accent: Color(0xFF0071E3),
    field: Color(0x0E000000),
    hover: Color(0x0D000000),
    paletteGlass: Color(0x8CFFFFFF),
    rim: Color(0x99FFFFFF),
    highlight: Color(0xF2FFFFFF),
    glow: Color(0x59FFFFFF),
    paletteShadow: Color(0x38000000),
    avatarTop: Color(0xFFA9ADB6),
    avatarBottom: Color(0xFF878B94),
  );

  static const dark = ShellColors(
    fg: Color(0xFFF5F5F7),
    fg2: Color(0xFFAEAEB3),
    separator: Color(0x17FFFFFF),
    accent: Color(0xFF0A84FF),
    field: Color(0x12FFFFFF),
    hover: Color(0x0FFFFFFF),
    paletteGlass: Color(0x941E2024),
    rim: Color(0x24FFFFFF),
    highlight: Color(0x38FFFFFF),
    glow: Color(0x0AFFFFFF),
    paletteShadow: Color(0x99000000),
    avatarTop: Color(0xFF71757E),
    avatarBottom: Color(0xFF565A62),
  );

  final Color fg;
  final Color fg2;
  final Color separator;
  final Color accent;
  final Color field;
  final Color hover;
  final Color paletteGlass;
  final Color rim;
  final Color highlight;
  final Color glow;
  final Color paletteShadow;
  final Color avatarTop;
  final Color avatarBottom;
}

/// Provides [ShellColors] to the shell's widgets.
class ShellTheme extends InheritedWidget {
  const ShellTheme({super.key, required this.colors, required super.child});

  final ShellColors colors;

  /// The nearest colors, or the light or dark default for the platform.
  static ShellColors of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<ShellTheme>();
    if (theme != null) return theme.colors;
    final brightness =
        MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    return brightness == Brightness.dark ? ShellColors.dark : ShellColors.light;
  }

  @override
  bool updateShouldNotify(ShellTheme oldWidget) => colors != oldWidget.colors;
}

/// A grey monogram avatar, as everywhere in the app.
class MonogramAvatar extends StatelessWidget {
  const MonogramAvatar({super.key, required this.initials, this.size = 24});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = ShellTheme.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.avatarTop, c.avatarBottom],
        ),
      ),
      child: Text(
        initials,
        maxLines: 1,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
