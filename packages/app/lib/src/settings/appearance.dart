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
  return (
    light: buildMgTheme(
      MgColors.light.copyWith(accent: accent.light),
      metrics: metrics,
    ),
    dark: buildMgTheme(
      MgColors.dark.copyWith(accent: accent.dark),
      metrics: metrics,
    ),
  );
}

/// The theme to show right now: the chosen one, or dark while the night
/// schedule says so. Re-evaluated when the schedule's next boundary passes.
final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  final theme = ref.watch(preferencesProvider.select((p) => p.theme));
  final schedule = ref.watch(
    preferencesProvider.select((p) => p.nightSchedule),
  );
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
/// design tokens; the others keep its softness with another hue.
({WallpaperColors light, WallpaperColors dark}) wallpaperColors(
  WallpaperPreset preset,
) => switch (preset) {
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

/// Behind the chats: the chosen gradient, a plain color or the user's
/// picture, cross-faded when the choice changes.
class ChatBackground extends ConsumerWidget {
  const ChatBackground({super.key});

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
    final c = MgColors.of(context);
    final child = switch (p.kind) {
      WallpaperKind.plain => ColoredBox(
        key: const ValueKey('plain'),
        color: plainChatBackground(c),
        child: const SizedBox.expand(),
      ),
      WallpaperKind.image when p.image != null => WallpaperImage(
        key: ValueKey('image:${p.image}:${p.blur}'),
        path: p.image!,
        blur: p.blur,
      ),
      _ => GradientWallpaper(
        key: ValueKey('gradient:${p.preset.name}'),
        preset: p.preset,
      ),
    };
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      child: child,
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
