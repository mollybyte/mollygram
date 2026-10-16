import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'preferences.dart';

/// The accent of [choice] in each theme, after the macOS accent colors,
/// toned down where the system one is loud.
({Color light, Color dark}) accentColors(AccentChoice choice) =>
    switch (choice) {
      AccentChoice.violet => (
        light: const Color(0xFF6142E0),
        dark: const Color(0xFF9F82FF),
      ),
      AccentChoice.blue => (
        light: MgColors.light.accent,
        dark: MgColors.dark.accent,
      ),
      AccentChoice.indigo => (
        light: const Color(0xFF5856D6),
        dark: const Color(0xFF6E6CF0),
      ),
      AccentChoice.teal => (
        light: const Color(0xFF0F8A96),
        dark: const Color(0xFF3FB8C6),
      ),
      AccentChoice.green => (
        light: const Color(0xFF2B8A45),
        dark: const Color(0xFF3CBF64),
      ),
      AccentChoice.orange => (
        light: const Color(0xFFC8630E),
        dark: const Color(0xFFF0962E),
      ),
      AccentChoice.graphite => (
        light: const Color(0xFF6E6E73),
        dark: const Color(0xFF98989D),
      ),
    };

/// The app themes for [preferences]: the design tokens with the chosen
/// accent, corners and density.
({ThemeData light, ThemeData dark}) appThemes(Preferences preferences) {
  final accent = accentColors(preferences.accent);
  final metrics = MgMetrics(
    mediaRadius: preferences.mediaCorner.radius,
    compact: preferences.compactLayout,
  );
  // A gradient tints the surfaces to match; the plain card and a picture
  // take the Stage window's own Mist tokens.
  final tint = preferences.wallpaperKind == WallpaperKind.gradient
      ? surfaceTint(preferences.wallpaperPreset)
      : surfaceTint(WallpaperPreset.mist);
  final light = tint?.light(MgColors.light) ?? MgColors.light;
  final blur = blurThemeActive(preferences);
  final dark = blur
      ? vesperBlur(MgColors.dark, preferences.blurOpacity)
      : tint?.dark(MgColors.dark) ?? MgColors.dark;
  return (
    light: buildMgTheme(light.copyWith(accent: accent.light), metrics: metrics),
    dark: buildMgTheme(
      dark.copyWith(
        accent: accent.dark,
        // The light violet of the dark theme is too pale under the white
        // text of the selected row.
        selection: preferences.accent == AccentChoice.violet
            ? const Color(0xFF6F4FEA)
            : null,
        // The blurred palette's own on-accent text is tuned for amber.
        onAccent: blur ? MgColors.dark.onAccent : null,
        onAccentSecondary: blur ? MgColors.dark.onAccentSecondary : null,
      ),
      metrics: metrics,
    ),
  );
}

/// Whether the Vesper Blur theme is on and can be shown: the blur is a
/// macOS window effect, so elsewhere the choice is kept but not applied.
bool blurThemeActive(Preferences preferences) =>
    preferences.blurTheme && Platform.isMacOS;

/// The Vesper Blur palette: a deep warm graphite with a soft amber accent.
///
/// The frame and the card are translucent so the blurred desktop shows
/// through ([opacity] is how much of the window stays); the glass layer
/// above them keeps its own fill. The text is warm off-white, bright enough
/// to stay above 4.5:1 on the frame over any desktop the blur can show (the
/// native material darkens it first).
MgColors vesperBlur(MgColors base, double opacity) => base.copyWith(
  fg: const Color(0xFFF3EEE7),
  fg2: const Color(0xFFC6BCB0),
  muted: const Color(0xFF9D9388),
  accent: const Color(0xFFE0A458),
  onAccent: const Color(0xFF1B1611),
  onAccentSecondary: const Color(0xB31B1611),
  separator: const Color(0x1FF3EEE7),
  hover: const Color(0x0FF3EEE7),
  field: const Color(0x14F3EEE7),
  avatarTop: const Color(0xFF5C544B),
  avatarBottom: const Color(0xFF443E37),
  glass: const Color(0xDC26221E),
  glassSolid: const Color(0xF026221E),
  rim: const Color(0x1AFFFFFF),
  highlight: const Color(0x24FFFFFF),
  frame: const Color(0xFF1A1714).withValues(alpha: opacity),
  card: const Color(0xFF24201C)
      .withValues(alpha: (opacity * 0.5).clamp(0.15, 1.0)),
);

/// One wallpaper's tint of the window and the text: the window frame and
/// the chat card, the glass fill and rim, the secondary and muted text, so
/// they carry that wallpaper's hue instead of the classic one.
typedef SurfaceTint = ({
  MgColors Function(MgColors) light,
  MgColors Function(MgColors) dark,
});

/// How [preset] tints the surfaces, or null for the gradients that keep
/// the classic tokens.
///
/// The three tinted presets come from the colours canvas: Mist is the
/// Stage window's own soft lavender (frame, text and avatars as on the
/// fresh-directions canvas), Sage the Telegram gradient at about half its
/// saturation, Linen a warm paper neutral.
SurfaceTint? surfaceTint(WallpaperPreset preset) => switch (preset) {
  WallpaperPreset.mist => (
    light: (c) => c.copyWith(
      fg: const Color(0xFF18161E),
      fg2: const Color(0xFF5C5768),
      muted: const Color(0xFF6E6978),
      separator: const Color(0x1F1C1A22),
      hover: const Color(0x0F1C1A22),
      field: const Color(0x0F1C1A22),
      avatarTop: const Color(0xFFCFC8DC),
      avatarBottom: const Color(0xFFA79EB8),
      glass: const Color(0x80FBFAFD),
      glassSolid: const Color(0xF0F6F4F9),
      rim: const Color(0xD9FFFFFF),
      shadow: const Color(0x1A281450),
      frame: const Color(0xFFE7E3EE),
    ),
    dark: (c) => c.copyWith(
      fg: const Color(0xFFF7F5FB),
      fg2: const Color(0xFFB9B4C6),
      muted: const Color(0xFF9A94A8),
      separator: const Color(0x1FEEEAF5),
      hover: const Color(0x0FEEEAF5),
      field: const Color(0x0FEEEAF5),
      avatarTop: const Color(0xFF5B5468),
      avatarBottom: const Color(0xFF433D4F),
      glass: const Color(0x80262330),
      glassSolid: const Color(0xF0262330),
      rim: const Color(0x1AFFFFFF),
      highlight: const Color(0x24FFFFFF),
      frame: const Color(0xFF1E1B25),
      card: const Color(0xFF2A2733),
    ),
  ),
  WallpaperPreset.sage => (
    light: (c) => c.copyWith(
      fg2: const Color(0xFF5E645C),
      muted: const Color(0xFF6A6D63),
      glass: const Color(0x80FFFFFF),
      glassSolid: const Color(0xF0F5F7F2),
      rim: const Color(0xCCFFFFFF),
      shadow: const Color(0x26202A1A),
      frame: const Color(0xFFE1E6DE),
    ),
    dark: (c) => c.copyWith(
      fg2: const Color(0xFF9AA6A8),
      muted: const Color(0xFF96A1A5),
      glass: const Color(0x801C2226),
      glassSolid: const Color(0xF0222A2E),
      rim: const Color(0x1CFFFFFF),
      highlight: const Color(0x26FFFFFF),
      frame: const Color(0xFF192023),
      card: const Color(0xFF22292D),
    ),
  ),
  WallpaperPreset.linen => (
    light: (c) => c.copyWith(
      fg2: const Color(0xFF6F685E),
      muted: const Color(0xFF77706A),
      glass: const Color(0x85FFFDF8),
      glassSolid: const Color(0xF0F8F5EF),
      rim: const Color(0xD9FFFFFF),
      field: const Color(0x0F3C2D14),
      shadow: const Color(0x262A2014),
      frame: const Color(0xFFECE7E0),
      card: const Color(0xFFFFFEFB),
    ),
    dark: (c) => c.copyWith(
      fg2: const Color(0xFFA39C92),
      muted: const Color(0xFFA0988E),
      glass: const Color(0x802C2824),
      glassSolid: const Color(0xF02A2622),
      rim: const Color(0x1AFFFFFF),
      highlight: const Color(0x21FFFFFF),
      frame: const Color(0xFF201D1A),
      card: const Color(0xFF2A2623),
    ),
  ),
  _ => null,
};

/// The theme to show right now: the chosen one, or dark while the night
/// schedule says so. Re-evaluated when the schedule's next boundary passes.
final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  final theme = ref.watch(preferencesProvider.select((p) => p.theme));
  final schedule = ref.watch(
    preferencesProvider.select((p) => p.nightSchedule),
  );
  // The blurred theme is dark only.
  if (ref.watch(preferencesProvider.select(blurThemeActive))) {
    return ThemeMode.dark;
  }
  if (!schedule.enabled) return theme;
  final now = ref.watch(clockProvider)();
  final timer = Timer(
    schedule.nextChange(now).difference(now) + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return schedule.isNight(now) ? ThemeMode.dark : theme;
});

/// The current time; tests swap it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The colors of one gradient wallpaper in one theme.
typedef WallpaperColors = ({Color base, List<Color> colors});

/// The gradient of [preset] in each theme. Classic is the one from the
/// design tokens; the others keep its softness with another hue, and the
/// first three also tint the surfaces (see [surfaceTint]).
({WallpaperColors light, WallpaperColors dark}) wallpaperColors(
  WallpaperPreset preset,
) => switch (preset) {
  WallpaperPreset.mist => (
    light: (
      base: const Color(0xFFE1E7ED),
      colors: const [
        Color(0xFFEEF2F6),
        Color(0xFFDCE3EA),
        Color(0xFFD3DCE5),
        Color(0xFFE6EBF0),
      ],
    ),
    dark: (
      base: const Color(0xFF191F26),
      colors: const [
        Color(0xFF222A33),
        Color(0xFF1C232B),
        Color(0xFF1A2129),
        Color(0xFF1E252D),
      ],
    ),
  ),
  WallpaperPreset.sage => (
    light: (
      base: const Color(0xFFD0DAC8),
      colors: const [
        Color(0xFFE3E5D2),
        Color(0xFFAFC6BB),
        Color(0xFFE2E3C6),
        Color(0xFFBFD0BB),
      ],
    ),
    dark: (
      base: const Color(0xFF192329),
      colors: const [
        Color(0xFF24333D),
        Color(0xFF1A262E),
        Color(0xFF2C3A43),
        Color(0xFF1D2A32),
      ],
    ),
  ),
  WallpaperPreset.linen => (
    light: (
      base: const Color(0xFFECE7DD),
      colors: const [
        Color(0xFFF8F5EE),
        Color(0xFFEFEBE2),
        Color(0xFFE6E0D4),
        Color(0xFFF1EDE4),
      ],
    ),
    dark: (
      base: const Color(0xFF1C1815),
      colors: const [
        Color(0xFF26221E),
        Color(0xFF201C18),
        Color(0xFF1A1714),
        Color(0xFF221E1A),
      ],
    ),
  ),
  WallpaperPreset.classic => (
    light: (
      base: MgColors.light.wallpaperBase,
      colors: MgColors.light.wallpaper,
    ),
    dark: (base: MgColors.dark.wallpaperBase, colors: MgColors.dark.wallpaper),
  ),
  WallpaperPreset.ocean => (
    light: (
      base: const Color(0xFFA9C4D4),
      colors: const [
        Color(0xFFCFE0E8),
        Color(0xFF6F9FBC),
        Color(0xFFBBD7DF),
        Color(0xFF86B1C7),
      ],
    ),
    dark: (
      base: const Color(0xFF17283A),
      colors: const [
        Color(0xFF274463),
        Color(0xFF1A2F45),
        Color(0xFF335371),
        Color(0xFF1F3850),
      ],
    ),
  ),
  WallpaperPreset.lavender => (
    light: (
      base: const Color(0xFFC3BBD6),
      colors: const [
        Color(0xFFE2DCEC),
        Color(0xFF9A8FC1),
        Color(0xFFD9CDE6),
        Color(0xFFB1A5D0),
      ],
    ),
    dark: (
      base: const Color(0xFF26223A),
      colors: const [
        Color(0xFF3D3660),
        Color(0xFF2A2544),
        Color(0xFF4A4270),
        Color(0xFF302A4C),
      ],
    ),
  ),
  WallpaperPreset.sand => (
    light: (
      base: const Color(0xFFD8C7A8),
      colors: const [
        Color(0xFFEEE3CC),
        Color(0xFFC3A170),
        Color(0xFFE7D8B4),
        Color(0xFFD0B585),
      ],
    ),
    dark: (
      base: const Color(0xFF2E2820),
      colors: const [
        Color(0xFF4A3F2F),
        Color(0xFF342C22),
        Color(0xFF5A4B36),
        Color(0xFF3C3226),
      ],
    ),
  ),
  WallpaperPreset.graphite => (
    light: (
      base: const Color(0xFFC9CBD1),
      colors: const [
        Color(0xFFE1E3E7),
        Color(0xFFA3A7B0),
        Color(0xFFD7D9DE),
        Color(0xFFB8BBC3),
      ],
    ),
    dark: (
      base: const Color(0xFF1E1F23),
      colors: const [
        Color(0xFF32343A),
        Color(0xFF232529),
        Color(0xFF3C3E45),
        Color(0xFF282A2F),
      ],
    ),
  ),
};

/// How long the theme takes to cross-fade; none with reduced motion.
Duration themeAnimationDuration(bool reduceMotion) =>
    reduceMotion ? Duration.zero : const Duration(milliseconds: 260);

/// Wraps the app so `MediaQuery.disableAnimationsOf` is true when either
/// macOS or the user's "Reduce motion" asks for it. Code that already
/// checks it, and Flutter's own widgets, follow both.
class ReduceMotionScope extends ConsumerWidget {
  const ReduceMotionScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduce = ref.watch(preferencesProvider.select((p) => p.reduceMotion));
    final data = MediaQuery.of(context);
    if (!reduce || data.disableAnimations) return child;
    return MediaQuery(
      data: data.copyWith(disableAnimations: true),
      child: child,
    );
  }
}

/// The plain background behind the chats when the wallpaper is off.
Color plainChatBackground(MgColors c) =>
    c.isDark ? const Color(0xFF17181A) : const Color(0xFFECEDEF);

/// Under a chat on its card: the chosen gradient or the user's own
/// picture; for the plain background nothing, and the card's solid colour
/// shows.
class ChatCardBackground extends ConsumerWidget {
  const ChatCardBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(
      preferencesProvider.select(
        (p) => (
          kind: p.wallpaperKind,
          preset: p.wallpaperPreset,
          image: p.wallpaperImage,
          blur: p.wallpaperBlur,
        ),
      ),
    );
    final image = p.image;
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      child: switch (p.kind) {
        WallpaperKind.image when image != null => WallpaperImage(
          key: ValueKey('image:$image:${p.blur}'),
          path: image,
          blur: p.blur,
        ),
        WallpaperKind.gradient => SizedBox.expand(
          key: ValueKey('gradient:${p.preset.name}'),
          child: GradientWallpaper(preset: p.preset),
        ),
        _ => const SizedBox.expand(key: ValueKey('none')),
      },
    );
  }
}

/// The four-point gradient of [preset] in the current theme.
class GradientWallpaper extends StatelessWidget {
  const GradientWallpaper({super.key, required this.preset});

  final WallpaperPreset preset;

  @override
  Widget build(BuildContext context) {
    final colors = wallpaperColors(preset);
    final set = MgColors.of(context).isDark ? colors.dark : colors.light;
    return Wallpaper(base: set.base, colors: set.colors);
  }
}

/// A picture of the user's own, filling the area, dimmed a little in the
/// dark theme so white text and glass still read; blurred when asked.
/// A picture that can't be read falls back to the plain color.
class WallpaperImage extends StatelessWidget {
  const WallpaperImage({super.key, required this.path, this.blur = false});

  final String path;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    Widget image = Image.file(
      File(path),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => ColoredBox(color: plainChatBackground(c)),
    );
    if (blur) {
      image = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: image,
      );
    }
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (c.isDark) const ColoredBox(color: Color(0x40000000)),
        ],
      ),
    );
  }
}

/// Asset of each Dock icon choice; the brand icon needs none, the app
/// ships with it.
String? appIconAsset(AppIconChoice choice) => switch (choice) {
  AppIconChoice.crimson => null,
  AppIconChoice.blue => 'assets/app_icon/blue.png',
  AppIconChoice.graphite => 'assets/app_icon/graphite.png',
};

/// Tells macOS which Dock icon to show. Swapped in tests.
Future<void> Function(String? asset) applyAppIcon = _applyAppIconWithSystem;

const _appIconChannel = MethodChannel('mollygram/app_icon');

Future<void> _applyAppIconWithSystem(String? asset) async {
  if (!Platform.isMacOS) return;
  try {
    if (asset == null) {
      await _appIconChannel.invokeMethod<void>('reset');
    } else {
      final bytes = await rootBundle.load(asset);
      await _appIconChannel.invokeMethod<void>(
        'set',
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }
  } on MissingPluginException {
    // An older runner without the channel keeps the icon it has.
  }
}

/// Applies the chosen Dock icon at launch and whenever it changes.
class AppIconApplier extends ConsumerStatefulWidget {
  const AppIconApplier({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppIconApplier> createState() => _AppIconApplierState();
}

class _AppIconApplierState extends ConsumerState<AppIconApplier> {
  AppIconChoice? _applied;

  void _apply(AppIconChoice choice) {
    if (choice == _applied) return;
    _applied = choice;
    unawaited(applyAppIcon(appIconAsset(choice)));
  }

  @override
  Widget build(BuildContext context) {
    final choice = ref.watch(preferencesProvider.select((p) => p.appIcon));
    _apply(choice);
    return widget.child;
  }
}

/// Scales message text to the size chosen in Appearance. The default 13
/// leaves text as designed.
class MessageTextSize extends ConsumerWidget {
  const MessageTextSize({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(preferencesProvider.select((p) => p.textSize));
    if (size == Preferences.defaultTextSize) return child;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(size / Preferences.defaultTextSize),
      ),
      child: child,
    );
  }
}
