import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'appearance.dart';
import 'preferences.dart';
import 'settings_style.dart';

/// Appearance: theme, accent, wallpaper, message text size and motion.
/// Every choice applies at once.
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final p = ref.watch(preferencesProvider);
    void update(Preferences Function(Preferences) change) =>
        ref.read(preferencesProvider.notifier).update(change);

    return SettingsPage(
      children: [
        SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final (mode, label) in [
                    (ThemeMode.system, l10n.themeAuto),
                    (ThemeMode.light, l10n.themeLight),
                    (ThemeMode.dark, l10n.themeDark),
                  ])
                    _ThemeCard(
                      key: ValueKey('theme.${mode.name}'),
                      mode: mode,
                      label: label,
                      selected: p.theme == mode,
                      onTap: () => update((p) => p.copyWith(theme: mode)),
                    ),
                ],
              ),
            ),
            SettingsRow(
              title: l10n.accentColor,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final choice in AccentChoice.values)
                    _AccentDot(
                      key: ValueKey('accent.${choice.name}'),
                      choice: choice,
                      label: _accentName(l10n, choice),
                      selected: p.accent == choice,
                      onTap: () => update((p) => p.copyWith(accent: choice)),
                    ),
                ],
              ),
            ),
          ],
        ),
        SettingsGroup(
          footer: SettingsFooter(l10n.chatWallpaperHint),
          children: [
            SettingsSwitchRow(
              key: const ValueKey('wallpaper'),
              title: l10n.chatWallpaper,
              value: p.wallpaper,
              onChanged: (v) => update((p) => p.copyWith(wallpaper: v)),
            ),
          ],
        ),
        SettingsGroup(
          title: l10n.messageTextSize,
          children: [
            _TextSizePreview(size: p.textSize),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
              child: Row(
                children: [
                  Text('A', style: mgTextStyle(c, size: 11, color: c.fg2)),
                  Expanded(
                    child: _TextSizeSlider(
                      value: p.textSize,
                      label: l10n.textSizeValue('${p.textSize}'),
                      onChanged: (v) => update((p) => p.copyWith(textSize: v)),
                    ),
                  ),
                  Text('A', style: mgTextStyle(c, size: 17, color: c.fg2)),
                ],
              ),
            ),
          ],
        ),
        SettingsGroup(
          footer: SettingsFooter(l10n.reduceMotionHint),
          children: [
            SettingsSwitchRow(
              key: const ValueKey('reduceMotion'),
              title: l10n.reduceMotion,
              value: p.reduceMotion,
              onChanged: (v) => update((p) => p.copyWith(reduceMotion: v)),
            ),
          ],
        ),
      ],
    );
  }
}

String _accentName(AppLocalizations l10n, AccentChoice choice) =>
    switch (choice) {
      AccentChoice.blue => l10n.accentBlue,
      AccentChoice.indigo => l10n.accentIndigo,
      AccentChoice.teal => l10n.accentTeal,
      AccentChoice.green => l10n.accentGreen,
      AccentChoice.orange => l10n.accentOrange,
      AccentChoice.graphite => l10n.accentGraphite,
    };

/// A miniature window in one theme, as System Settings shows them. Auto is
/// split: light on the left, dark on the right.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    super.key,
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _width = 96.0;
  static const _height = 62.0;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final window = switch (mode) {
      ThemeMode.light => const _MiniWindow(colors: MgColors.light),
      ThemeMode.dark => const _MiniWindow(colors: MgColors.dark),
      ThemeMode.system => const Stack(
        children: [
          Positioned.fill(child: _MiniWindow(colors: MgColors.light)),
          Positioned.fill(
            child: ClipRect(
              clipper: _RightHalf(),
              child: _MiniWindow(colors: MgColors.dark),
            ),
          ),
        ],
      ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              AnimatedContainer(
                duration: settingsMotionOf(context),
                curve: settingsCurve,
                width: _width + 6,
                height: _height + 6,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? c.accent : c.accent.withValues(alpha: 0),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: window,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: mgTextStyle(
                  c,
                  size: MgType.caption,
                  weight: selected ? FontWeight.w600 : null,
                  color: selected ? c.fg : c.fg2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RightHalf extends CustomClipper<Rect> {
  const _RightHalf();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(_RightHalf oldClipper) => false;
}

/// A sidebar, two message lines and the window background, in [colors].
class _MiniWindow extends StatelessWidget {
  const _MiniWindow({required this.colors});

  final MgColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final accent = MgColors.of(context).accent;
    Widget line(double width, Color color) => Container(
      width: width,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.wallpaper[0], c.wallpaper[1]],
        ),
        border: Border.all(color: c.separator, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 30,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.glassSolid,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.fromLTRB(4, 9, 4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(20, accent),
                const SizedBox(height: 4),
                line(16, c.fg2.withValues(alpha: 0.5)),
                const SizedBox(height: 4),
                line(18, c.fg2.withValues(alpha: 0.5)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 6, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(34, c.bubbleIn),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: line(28, c.bubbleOut),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    super.key,
    required this.choice,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AccentChoice choice;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final colors = accentColors(choice);
    final color = c.isDark ? colors.dark : colors.light;
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.separator, width: 0.5),
                ),
                child: AnimatedScale(
                  duration: settingsMotionOf(context),
                  curve: settingsCurve,
                  scale: selected ? 1 : 0,
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFFFFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sample message at the chosen size, as the chats will show it.
class _TextSizePreview extends StatelessWidget {
  const _TextSizePreview({required this.size});

  final int size;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final scale = size / Preferences.defaultTextSize;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: AnimatedSize(
        duration: settingsMotionOf(context),
        curve: settingsCurve,
        alignment: Alignment.topLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonogramAvatar(name: l10n.previewSender, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.previewSender,
                      style: mgTextStyle(c, weight: FontWeight.w600),
                    ),
                    Text(l10n.previewMessage, style: mgTextStyle(c)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 12 to 17 point slider with a stop per size.
class _TextSizeSlider extends StatelessWidget {
  const _TextSizeSlider({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: c.accent,
        inactiveTrackColor: c.field,
        thumbColor: const Color(0xFFFFFFFF),
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 8,
          elevation: 1.5,
        ),
        activeTickMarkColor: c.onAccent.withValues(alpha: 0.6),
        inactiveTickMarkColor: c.fg2.withValues(alpha: 0.5),
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.5),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        key: const ValueKey('textSize'),
        value: value.toDouble(),
        min: Preferences.minTextSize.toDouble(),
        max: Preferences.maxTextSize.toDouble(),
        divisions: Preferences.maxTextSize - Preferences.minTextSize,
        semanticFormatterCallback: (_) => label,
        onChanged: (v) => onChanged(v.round()),
      ),
    );
  }
}
