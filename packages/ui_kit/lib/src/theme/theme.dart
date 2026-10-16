import 'package:flutter/material.dart';

import 'colors.dart';
import 'metrics.dart';

/// Builds the app theme around [colors]: system font, no ink splashes,
/// the single accent as the primary color.
ThemeData buildMgTheme(
  MgColors colors, {
  MgMetrics metrics = MgMetrics.defaults,
}) {
  final base = ThemeData(
    brightness: colors.brightness,
    fontFamily: mgFontFamily,
    fontFamilyFallback: mgFontFamilyFallback,
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
    extensions: [colors, metrics],
  );
  return base.copyWith(
    textTheme: _unified(
      base.textTheme.apply(bodyColor: colors.fg, displayColor: colors.fg),
    ),
  );
}

/// Material's text theme tracks and spaces its lines its own way (+0.25 and
/// 1.43 for body text). A style that names only a size inherits both from
/// the ambient text style, so the same 13 px came out differently wherever
/// no [mgTextStyle] sat above it. Every role gets the system tracking and
/// the UI's line height instead.
TextTheme _unified(TextTheme theme) {
  TextStyle? unify(TextStyle? style, {bool ambient = false}) {
    if (style == null) return null;
    return style.copyWith(
      fontFamily: mgFontFamily,
      fontFamilyFallback: mgFontFamilyFallback,
      height: 1.4,
      // Text that sets only its size inherits this: no tracking of its own
      // at the body size, so it never gets the tracking of another size.
      letterSpacing: ambient ? 0 : mgTracking(style.fontSize ?? MgType.body),
    );
  }

  return theme.copyWith(
    displayLarge: unify(theme.displayLarge),
    displayMedium: unify(theme.displayMedium),
    displaySmall: unify(theme.displaySmall),
    headlineLarge: unify(theme.headlineLarge),
    headlineMedium: unify(theme.headlineMedium),
    headlineSmall: unify(theme.headlineSmall),
    titleLarge: unify(theme.titleLarge),
    titleMedium: unify(theme.titleMedium),
    titleSmall: unify(theme.titleSmall),
    bodyLarge: unify(theme.bodyLarge),
    bodyMedium: unify(theme.bodyMedium, ambient: true),
    bodySmall: unify(theme.bodySmall),
    labelLarge: unify(theme.labelLarge),
    labelMedium: unify(theme.labelMedium),
    labelSmall: unify(theme.labelSmall),
  );
}

/// The system font. `CupertinoSystemText` is the family the engine maps
/// to the native UI font with all of its weights and the text optical size
/// (SF Pro Text on macOS); asking for `.AppleSystemUIFont` or leaving the
/// family empty gets only regular and bold there, so semibold and medium
/// come out as heavy bold.
const String mgFontFamily = 'CupertinoSystemText';

/// Other platforms: Segoe UI on Windows, then common Linux UI fonts.
const List<String> mgFontFamilyFallback = [
  '.AppleSystemUIFont',
  'Segoe UI Variable Text',
  'Segoe UI',
  'Inter',
  'Cantarell',
  'Ubuntu',
  'Noto Sans',
  'Roboto',
  'sans-serif',
];

/// The weights the UI uses. Nothing in the app is bold: titles and names
/// are [medium], only the header title and badges are [semibold].
abstract final class MgWeight {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
}

/// Type scale. Everything uses the system font; sizes are in logical
/// pixels and whole numbers only, on the steps TelegramSwift uses
/// (11/12/13/14/15/18): half-pixel steps next to each other read as
/// mismatched text. The base size is 14, a step over the official 13,
/// which read small on a real screen.
abstract final class MgType {
  /// Body text: 14.
  static const double body = 14;

  /// Chat titles in the header, the composer: 14.
  static const double title = 14;

  /// Folder tabs: 13.
  static const double tab = 13;

  /// Date pills, reply and forward blocks: 13.
  static const double small = 13;

  /// Times in the chat list, header subtitles, folder counters: 12.
  static const double caption = 12;

  /// Message meta, badges, file sizes: 12.
  static const double meta = 12;

  /// Fine print: 11.
  static const double tiny = 11;

  /// Message text: 14, one step over the official client's 13.
  static const double message = 14;
}

/// SF Pro's tracking for [size], as the system applies it to its own
/// text: a touch wider below 12 px, tighter from 13 px up.
double mgTracking(double size) {
  if (size <= 11) return 0.06;
  if (size < 13) return 0;
  if (size < 14) return -0.08;
  if (size < 16) return -0.15;
  if (size < 20) return -0.24;
  return -0.3;
}

/// The base text style: system font, 14 px, line height 1.4, system
/// tracking.
TextStyle mgTextStyle(
  MgColors colors, {
  double size = MgType.body,
  FontWeight? weight,
  Color? color,
  double height = 1.4,
}) => TextStyle(
  fontFamily: mgFontFamily,
  fontFamilyFallback: mgFontFamilyFallback,
  fontSize: size,
  height: height,
  fontWeight: weight,
  color: color ?? colors.fg,
  letterSpacing: mgTracking(size),
);
