import 'package:flutter/widgets.dart';

/// Colors of design/Plugins.dc.html (the `.app` and `.app.dark` variables).
///
/// Local to this screen until the shared theme lands in ui_kit.
@immutable
class PluginsColors {
  const PluginsColors._({
    required this.dark,
    required this.pane,
    required this.surface,
    required this.fg,
    required this.fg2,
    required this.sep,
    required this.accent,
    required this.hover,
    required this.field,
    required this.off,
    required this.code,
    required this.glass,
    required this.rim,
    required this.hi,
    required this.glow,
    required this.shadow,
    required this.wallBase,
    required this.wall,
  });

  final bool dark;
  final Color pane;
  final Color surface;
  final Color fg;
  final Color fg2;
  final Color sep;
  final Color accent;
  final Color hover;
  final Color field;

  /// A switch that is off.
  final Color off;
  final Color code;
  final Color glass;
  final Color rim;
  final Color hi;
  final Color glow;
  final Color shadow;
  final Color wallBase;

  /// The four points of the Telegram gradient wallpaper, in mockup order.
  final List<Color> wall;

  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFFF9F0A);

  static const light = PluginsColors._(
    dark: false,
    pane: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    fg: Color(0xFF1D1D1F),
    fg2: Color(0xFF6E6E73),
    sep: Color(0x14000000),
    accent: Color(0xFF0071E3),
    hover: Color(0x0D000000),
    field: Color(0x0E000000),
    off: Color(0xFFD9D9DE),
    code: Color(0xFFF0F0F3),
    glass: Color(0x6BFFFFFF),
    rim: Color(0x99FFFFFF),
    hi: Color(0xF2FFFFFF),
    glow: Color(0x59FFFFFF),
    shadow: Color(0x291E3214),
    wallBase: Color(0xFFB5C99E),
    wall: [
      Color(0xFFDBDDBB),
      Color(0xFF6BA587),
      Color(0xFFD5D88D),
      Color(0xFF88B884),
    ],
  );

  static const darkColors = PluginsColors._(
    dark: true,
    pane: Color(0xFF1C1C1E),
    surface: Color(0xFF2A2A2D),
    fg: Color(0xFFF5F5F7),
    fg2: Color(0xFFA1A1A6),
    sep: Color(0x17FFFFFF),
    accent: Color(0xFF0A84FF),
    hover: Color(0x0FFFFFFF),
    field: Color(0x12FFFFFF),
    off: Color(0xFF48484C),
    code: Color(0xFF232326),
    glass: Color(0x6B1C1E22),
    rim: Color(0x24FFFFFF),
    hi: Color(0x38FFFFFF),
    glow: Color(0x0AFFFFFF),
    shadow: Color(0x73000000),
    wallBase: Color(0xFF1A2A35),
    wall: [
      Color(0xFF2D4A5C),
      Color(0xFF1C3442),
      Color(0xFF3B5465),
      Color(0xFF203845),
    ],
  );

  static PluginsColors of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PluginsTheme>()?.colors ??
      light;
}

/// Provides [PluginsColors] to the screen's widgets.
class PluginsTheme extends InheritedWidget {
  const PluginsTheme({super.key, required this.colors, required super.child});

  final PluginsColors colors;

  @override
  bool updateShouldNotify(PluginsTheme old) => old.colors != colors;
}
