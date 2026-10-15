import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'appearance.dart';
import 'preferences.dart';
import 'settings_style.dart';

/// Appearance: theme and night schedule, accent, chat background, message
/// text size, corners and density, the Dock icon and motion. Every choice
/// applies at once.
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  Future<void> _choosePicture(WidgetRef ref) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: ['png', 'jpg', 'jpeg', 'heic', 'webp'],
          uniformTypeIdentifiers: ['public.image'],
        ),
      ],
    );
    if (file == null) return;
    ref
        .read(preferencesProvider.notifier)
        .update(
          (p) => p.copyWith(
            wallpaperKind: WallpaperKind.image,
            wallpaperImage: file.path,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final p = ref.watch(preferencesProvider);
    void update(Preferences Function(Preferences) change) =>
        ref.read(preferencesProvider.notifier).update(change);
    final schedule = p.nightSchedule;

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
          footer: SettingsFooter(l10n.nightScheduleHint),
          children: [
            SettingsSwitchRow(
              key: const ValueKey('nightSchedule'),
              title: l10n.nightSchedule,
              value: schedule.enabled,
              onChanged: (v) => update(
                (p) => p.copyWith(nightSchedule: schedule.copyWith(enabled: v)),
              ),
            ),
            _Reveal(
              shown: schedule.enabled,
              child: Column(
                children: [
                  SettingsRow(
                    title: l10n.nightFrom,
                    trailing: _TimePicker(
                      key: const ValueKey('nightFrom'),
                      minutes: schedule.from,
                      onChanged: (m) => update(
                        (p) => p.copyWith(
                          nightSchedule: schedule.copyWith(from: m),
                        ),
                      ),
                    ),
                  ),
                  SettingsRow(
                    title: l10n.nightTo,
                    trailing: _TimePicker(
                      key: const ValueKey('nightTo'),
                      minutes: schedule.to,
                      onChanged: (m) => update(
                        (p) =>
                            p.copyWith(nightSchedule: schedule.copyWith(to: m)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (Platform.isMacOS)
          SettingsGroup(
            footer: SettingsFooter(l10n.blurThemeHint),
            children: [
              SettingsSwitchRow(
                key: const ValueKey('blurTheme'),
                title: l10n.blurTheme,
                value: p.blurTheme,
                onChanged: (v) => update((p) => p.copyWith(blurTheme: v)),
              ),
              _Reveal(
                shown: p.blurTheme,
                child: SettingsRow(
                  title: l10n.blurOpacity,
                  trailing: SizedBox(
                    width: 180,
                    child: _BlurOpacitySlider(
                      value: p.blurOpacity,
                      onChanged: (v) =>
                          update((p) => p.copyWith(blurOpacity: v)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        SettingsGroup(
          title: l10n.chatBackground,
          footer: SettingsFooter(l10n.chatBackgroundHint),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preset in WallpaperPreset.values)
                    _WallpaperTile(
                      key: ValueKey('wallpaper.${preset.name}'),
                      label: _wallpaperName(l10n, preset),
                      selected:
                          p.wallpaperKind == WallpaperKind.gradient &&
                          p.wallpaperPreset == preset,
                      onTap: () => update(
                        (p) => p.copyWith(
                          wallpaperKind: WallpaperKind.gradient,
                          wallpaperPreset: preset,
                        ),
                      ),
                      child: GradientWallpaper(preset: preset),
                    ),
                  _WallpaperTile(
                    key: const ValueKey('wallpaper.plain'),
                    label: l10n.wallpaperPlain,
                    selected: p.wallpaperKind == WallpaperKind.plain,
                    onTap: () => update(
                      (p) => p.copyWith(wallpaperKind: WallpaperKind.plain),
                    ),
                    child: ColoredBox(color: c.card),
                  ),
                  _WallpaperTile(
                    key: const ValueKey('wallpaper.image'),
                    label: l10n.wallpaperPicture,
                    selected: p.wallpaperKind == WallpaperKind.image,
                    onTap: () => p.wallpaperImage == null
                        ? _choosePicture(ref)
                        : update(
                            (p) =>
                                p.copyWith(wallpaperKind: WallpaperKind.image),
                          ),
                    child: p.wallpaperImage == null
                        ? ColoredBox(
                            color: c.field,
                            child: Center(
                              child: MgIcon(
                                MgIcons.plus,
                                size: 18,
                                color: c.fg2,
                              ),
                            ),
                          )
                        : Image.file(
                            File(p.wallpaperImage!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                ColoredBox(color: c.field),
                          ),
                  ),
                ],
              ),
            ),
            SettingsRow(
              key: const ValueKey('choosePicture'),
              title: p.wallpaperImage == null
                  ? l10n.choosePicture
                  : l10n.changePicture,
              onTap: () => _choosePicture(ref),
              chevron: true,
            ),
            _Reveal(
              shown: p.wallpaperKind == WallpaperKind.image,
              child: SettingsSwitchRow(
                key: const ValueKey('blurPicture'),
                title: l10n.blurPicture,
                value: p.wallpaperBlur,
                onChanged: (v) => update((p) => p.copyWith(wallpaperBlur: v)),
              ),
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
          title: l10n.layout,
          footer: SettingsFooter(l10n.compactLayoutHint),
          children: [
            SettingsRow(
              title: l10n.mediaCorners,
              trailing: _Segmented<MediaCorner>(
                value: p.mediaCorner,
                segments: [
                  for (final corner in MediaCorner.values)
                    (
                      value: corner,
                      key: ValueKey('corner.${corner.name}'),
                      child: _CornerSample(corner: corner),
                      label: _cornerName(l10n, corner),
                    ),
                ],
                onChanged: (v) => update((p) => p.copyWith(mediaCorner: v)),
              ),
            ),
            SettingsSwitchRow(
              key: const ValueKey('showArchiveRow'),
              title: l10n.showArchiveRow,
              value: !p.hideArchive,
              onChanged: (v) => update((p) => p.copyWith(hideArchive: !v)),
            ),
            SettingsSwitchRow(
              key: const ValueKey('compactLayout'),
              title: l10n.compactLayout,
              value: p.compactLayout,
              onChanged: (v) => update((p) => p.copyWith(compactLayout: v)),
            ),
          ],
        ),
        SettingsGroup(
          title: l10n.appIcon,
          footer: SettingsFooter(l10n.appIconHint),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                children: [
                  for (final choice in AppIconChoice.values) ...[
                    _AppIconTile(
                      key: ValueKey('appIcon.${choice.name}'),
                      choice: choice,
                      label: _appIconName(l10n, choice),
                      selected: p.appIcon == choice,
                      onTap: () => update((p) => p.copyWith(appIcon: choice)),
                    ),
                    const SizedBox(width: 14),
                  ],
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
      AccentChoice.violet => l10n.accentViolet,
      AccentChoice.blue => l10n.accentBlue,
      AccentChoice.indigo => l10n.accentIndigo,
      AccentChoice.teal => l10n.accentTeal,
      AccentChoice.green => l10n.accentGreen,
      AccentChoice.orange => l10n.accentOrange,
      AccentChoice.graphite => l10n.accentGraphite,
    };

String _wallpaperName(AppLocalizations l10n, WallpaperPreset preset) =>
    switch (preset) {
      WallpaperPreset.mist => l10n.wallpaperMist,
      WallpaperPreset.sage => l10n.wallpaperSage,
      WallpaperPreset.linen => l10n.wallpaperLinen,
      WallpaperPreset.classic => l10n.wallpaperClassic,
      WallpaperPreset.ocean => l10n.wallpaperOcean,
      WallpaperPreset.lavender => l10n.wallpaperLavender,
      WallpaperPreset.sand => l10n.wallpaperSand,
      WallpaperPreset.graphite => l10n.wallpaperGraphite,
    };

String _cornerName(AppLocalizations l10n, MediaCorner corner) =>
    switch (corner) {
      MediaCorner.small => l10n.cornerSmall,
      MediaCorner.medium => l10n.cornerMedium,
      MediaCorner.large => l10n.cornerLarge,
    };

String _appIconName(AppLocalizations l10n, AppIconChoice choice) =>
    switch (choice) {
      AppIconChoice.crimson => l10n.appIconCrimson,
      AppIconChoice.blue => l10n.appIconBlue,
      AppIconChoice.graphite => l10n.appIconGraphite,
    };

/// Rows that belong to a switch: slide open under it when it is on.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.shown, required this.child});

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: settingsMotionOf(context),
    curve: settingsCurve,
    alignment: Alignment.topCenter,
    child: shown ? child : const SizedBox(width: double.infinity, height: 0),
  );
}

/// A time of day as a pill that opens a list of half hours, as a date
/// field's popup does in System Settings.
class _TimePicker extends StatelessWidget {
  const _TimePicker({
    super.key,
    required this.minutes,
    required this.onChanged,
  });

  final int minutes;
  final ValueChanged<int> onChanged;

  static String format(BuildContext context, int minutes) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return PopupMenuButton<int>(
      initialValue: minutes,
      tooltip: '',
      position: PopupMenuPosition.under,
      color: c.glassSolid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      constraints: const BoxConstraints(maxHeight: 280, minWidth: 96),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (var m = 0; m < 24 * 60; m += 30)
          PopupMenuItem(
            value: m,
            height: 26,
            child: Text(
              format(context, m),
              style: mgTextStyle(
                c,
                weight: m == minutes ? FontWeight.w600 : null,
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
        decoration: BoxDecoration(
          color: c.field,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(format(context, minutes), style: mgTextStyle(c)),
            const SizedBox(width: 2),
            MgIcon(MgIcons.chevronUp, size: 12, color: c.fg2),
          ],
        ),
      ),
    );
  }
}

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
    return _Choice(
      label: label,
      selected: selected,
      onTap: onTap,
      width: _width,
      height: _height,
      radius: 10,
      child: window,
    );
  }
}

/// A framed preview with its label under it: the frame lights up in the
/// accent when selected.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.width,
    required this.height,
    required this.radius,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final inner = BorderRadius.circular(radius - 4);
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
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: settingsMotionOf(context),
                curve: settingsCurve,
                width: width + 6,
                height: height + 6,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: selected ? c.accent : c.accent.withValues(alpha: 0),
                    width: 2,
                  ),
                ),
                child: ClipRRect(borderRadius: inner, child: child),
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

/// One background to pick: a small live rendering of it, framed.
class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return _Choice(
      label: label,
      selected: selected,
      onTap: onTap,
      width: 72,
      height: 50,
      radius: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: c.separator, width: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        position: DecorationPosition.foreground,
        child: child,
      ),
    );
  }
}

/// One Dock icon to pick.
class _AppIconTile extends StatelessWidget {
  const _AppIconTile({
    super.key,
    required this.choice,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppIconChoice choice;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Choice(
    label: label,
    selected: selected,
    onTap: onTap,
    width: 56,
    height: 56,
    radius: 16,
    child: Image.asset(
      appIconAsset(choice) ?? 'assets/app_icon/crimson.png',
      width: 56,
      height: 56,
      filterQuality: FilterQuality.medium,
    ),
  );
}

/// A photo corner at the chosen radius, as the segment's picture.
class _CornerSample extends StatelessWidget {
  const _CornerSample({required this.corner});

  final MediaCorner corner;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      width: 18,
      height: 14,
      decoration: BoxDecoration(
        color: c.fg2.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(corner.radius * 0.6),
      ),
    );
  }
}

/// A segmented control, as macOS draws one: a field with the selected
/// segment raised as a white (or dark) pill that slides between segments.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final List<({T value, Key key, Widget child, String label})> segments;
  final ValueChanged<T> onChanged;

  static const _segmentWidth = 44.0;
  static const _height = 24.0;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final index = segments.indexWhere((s) => s.value == value);
    return Container(
      height: _height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: settingsMotionOf(context),
            curve: settingsCurve,
            left: index * _segmentWidth,
            top: 0,
            bottom: 0,
            width: _segmentWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.isDark ? const Color(0xFF636366) : Colors.white,
                borderRadius: BorderRadius.circular(5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final segment in segments)
                Tooltip(
                  message: segment.label,
                  waitDuration: const Duration(milliseconds: 500),
                  child: Semantics(
                    button: true,
                    selected: segment.value == value,
                    label: segment.label,
                    excludeSemantics: true,
                    onTap: () => onChanged(segment.value),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        key: segment.key,
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(segment.value),
                        child: SizedBox(
                          width: _segmentWidth,
                          child: Center(child: segment.child),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
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

/// The window opacity of the blurred theme, 70 to 95 percent.
class _BlurOpacitySlider extends StatelessWidget {
  const _BlurOpacitySlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

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
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        key: const ValueKey('blurOpacity'),
        value: value.clamp(
          Preferences.minBlurOpacity,
          Preferences.maxBlurOpacity,
        ),
        min: Preferences.minBlurOpacity,
        max: Preferences.maxBlurOpacity,
        semanticFormatterCallback: (v) => '${(v * 100).round()}%',
        onChanged: onChanged,
      ),
    );
  }
}
