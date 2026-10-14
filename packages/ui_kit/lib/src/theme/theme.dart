import 'package:flutter/material.dart';

import 'colors.dart';

/// Builds the app theme around [colors]: system font, no ink splashes,
/// the single accent as the primary color.
ThemeData buildMgTheme(MgColors colors) {
  final base = ThemeData(
    brightness: colors.brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: colors.brightness,
      primary: colors.accent,
      onPrimary: colors.onAccent,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accent,
      selectionColor: colors.accent.withValues(alpha: 0.28),
    ),
    extensions: [colors],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: colors.fg,
      displayColor: colors.fg,
    ),
  );
}

/// Type scale from the mockup. Everything uses the system font; sizes are
/// in logical pixels and the base size is 13.
abstract final class MgType {
  /// Body text, message text: 13.
  static const double body = 13;

  /// Chat titles in the list and the header, the composer: 13.5.
  static const double title = 13.5;

  /// Folder tabs: 12.5.
  static const double tab = 12.5;

  /// Date pills: 12.
  static const double small = 12;

  /// Times in the chat list, header subtitles, folder counters: 11.5.
  static const double caption = 11.5;

  /// Message meta, badges, file sizes: 11.
  static const double meta = 11;
}

/// The base text style: system font, 13 px, line height 1.4.
TextStyle mgTextStyle(
  MgColors colors, {
  double size = MgType.body,
  FontWeight? weight,
  Color? color,
  double height = 1.4,
}) => TextStyle(
  fontSize: size,
  height: height,
  fontWeight: weight,
  color: color ?? colors.fg,
  letterSpacing: 0,
);
