import 'package:flutter/material.dart';
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
/// accent.
({ThemeData light, ThemeData dark}) appThemes(Preferences preferences) {
  final accent = accentColors(preferences.accent);
  return (
    light: buildMgTheme(MgColors.light.copyWith(accent: accent.light)),
    dark: buildMgTheme(MgColors.dark.copyWith(accent: accent.dark)),
  );
}

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

/// Behind the chats: the gradient wallpaper, or a plain color, cross-faded
/// when the choice changes.
class ChatBackground extends ConsumerWidget {
  const ChatBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpaper = ref.watch(preferencesProvider.select((p) => p.wallpaper));
    final c = MgColors.of(context);
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      child: wallpaper
          ? const Wallpaper(key: ValueKey('wallpaper'))
          : ColoredBox(
              key: const ValueKey('plain'),
              color: plainChatBackground(c),
              child: const SizedBox.expand(),
            ),
    );
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
