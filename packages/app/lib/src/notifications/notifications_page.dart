import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../window_drag_area.dart';
import 'notification_settings.dart';
import 'system_notifications.dart';

/// Whether macOS lets Mollygram show notifications; read again each time
/// the page opens, since the user may have changed it in System Settings.
final notificationPermissionProvider =
    FutureProvider.autoDispose<NotificationPermission>(
      (ref) => ref.watch(systemNotificationsProvider).permission(),
    );

/// Notifications settings, laid out like a pane of macOS System Settings.
/// On its own over the whole window, Esc or the back button calls
/// [onClose]; inside the settings window ([onClose] null) the window owns
/// both.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key, this.onClose});

  final VoidCallback? onClose;

  static final _systemSettings = Uri.parse(
    'x-apple.systempreferences:com.apple.Notifications-Settings.extension',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = _Palette.of(context);
    final settings = ref.watch(notificationSettingsProvider);
    final denied =
        ref.watch(notificationPermissionProvider).value ==
        NotificationPermission.denied;
    void update(NotificationSettings Function(NotificationSettings) change) =>
        ref.read(notificationSettingsProvider.notifier).update(change);

    final onClose = this.onClose;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): ?onClose},
      child: Focus(
        autofocus: onClose != null,
        child: ColoredBox(
          color: palette.pane,
          child: Stack(
            children: [
              Positioned.fill(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 56, 28, 48),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Header(title: l10n.notifications),
                            if (denied) ...[
                              const SizedBox(height: 20),
                              _Group(
                                children: [
                                  _Notice(
                                    text: l10n.notificationsDenied,
                                    action:
                                        l10n.notificationsOpenSystemSettings,
                                    onAction: () =>
                                        unawaited(launchUrl(_systemSettings)),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),
                            _Caption(l10n.notificationsSectionAlerts),
                            _Group(
                              children: [
                                _ToggleRow(
                                  label: l10n.notificationsShow,
                                  hint: l10n.notificationsShowHint,
                                  value: settings.enabled,
                                  onChanged: (v) =>
                                      update((s) => s.copyWith(enabled: v)),
                                ),
                                _ToggleRow(
                                  label: l10n.notificationsPreview,
                                  hint: l10n.notificationsPreviewHint,
                                  value: settings.showPreview,
                                  enabled: settings.enabled,
                                  onChanged: (v) =>
                                      update((s) => s.copyWith(showPreview: v)),
                                ),
                                _ToggleRow(
                                  label: l10n.notificationsSound,
                                  value: settings.sound,
                                  enabled: settings.enabled,
                                  onChanged: (v) =>
                                      update((s) => s.copyWith(sound: v)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _Caption(l10n.notificationsSectionBadge),
                            _Group(
                              children: [
                                _ToggleRow(
                                  label: l10n.notificationsBadge,
                                  value: settings.badge,
                                  onChanged: (v) =>
                                      update((s) => s.copyWith(badge: v)),
                                ),
                                _ToggleRow(
                                  label: l10n.notificationsBadgeMuted,
                                  value: settings.badgeIncludesMuted,
                                  enabled: settings.badge,
                                  onChanged: (v) => update(
                                    (s) => s.copyWith(badgeIncludesMuted: v),
                                  ),
                                ),
                                _ToggleRow(
                                  label: l10n.notificationsBadgeMessages,
                                  value: settings.badgeCountsMessages,
                                  enabled: settings.badge,
                                  onChanged: (v) => update(
                                    (s) => s.copyWith(badgeCountsMessages: v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null) ...[
                // The title bar is hidden: this strip drags the window.
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 38,
                  child: WindowDragArea(),
                ),
                // Level with the window buttons (centred 30 pt down).
                Positioned(
                  top: 14,
                  left: 84,
                  child: MgIconButton(
                    icon: MgIcons.back,
                    tooltip: l10n.back,
                    onPressed: onClose,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// System Settings colors: a gray pane with white grouped cards.
final class _Palette {
  const _Palette({
    required this.pane,
    required this.card,
    required this.off,
    required this.colors,
  });

  factory _Palette.of(BuildContext context) {
    final c = MgColors.of(context);
    final dark = c.brightness == Brightness.dark;
    return _Palette(
      pane: dark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
      card: dark ? const Color(0xFF2A2A2D) : const Color(0xFFFFFFFF),
      off: dark ? const Color(0xFF48484C) : const Color(0xFFD9D9DE),
      colors: c,
    );
  }

  final Color pane;
  final Color card;

  /// A switch that is off.
  final Color off;
  final MgColors colors;
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF5F57), Color(0xFFE5343B)],
            ),
          ),
          child: const Center(child: _BellGlyph(size: 22)),
        ),
        const SizedBox(width: 12),
        Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: c.fg,
            ),
          ),
        ),
      ],
    );
  }
}

/// A white bell, the System Settings icon for notifications.
class _BellGlyph extends StatelessWidget {
  const _BellGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _BellPainter());
}

class _BellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()..color = const Color(0xFFFFFFFF);
    final bell = Path()
      ..moveTo(12 * s, 3 * s)
      ..cubicTo(8.4 * s, 3 * s, 6.5 * s, 5.7 * s, 6.5 * s, 9 * s)
      ..lineTo(6.5 * s, 13.2 * s)
      ..lineTo(4.6 * s, 16.2 * s)
      ..cubicTo(4.3 * s, 16.7 * s, 4.6 * s, 17.4 * s, 5.2 * s, 17.4 * s)
      ..lineTo(18.8 * s, 17.4 * s)
      ..cubicTo(19.4 * s, 17.4 * s, 19.7 * s, 16.7 * s, 19.4 * s, 16.2 * s)
      ..lineTo(17.5 * s, 13.2 * s)
      ..lineTo(17.5 * s, 9 * s)
      ..cubicTo(17.5 * s, 5.7 * s, 15.6 * s, 3 * s, 12 * s, 3 * s)
      ..close();
    canvas
      ..drawPath(bell, paint)
      ..drawOval(
        Rect.fromCenter(
          center: Offset(12 * s, 19.2 * s),
          width: 4.4 * s,
          height: 3 * s,
        ),
        paint,
      );
  }

  @override
  bool shouldRepaint(_BellPainter oldDelegate) => false;
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: MgColors.of(context).fg2,
        ),
      ),
    ),
  );
}

/// A rounded card of rows with hairlines between them.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: p.colors.separator, spreadRadius: .5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(height: .5, color: p.colors.separator),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A setting with a switch. The whole row toggles it; a row that depends
/// on another switch dims while that one is off.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.enabled = true,
  });

  final String label;
  final String? hint;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return AnimatedOpacity(
      opacity: enabled ? 1 : .4,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: !enabled,
        child: MergeSemantics(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, style: TextStyle(color: c.fg)),
                            if (hint != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                hint!,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: c.fg2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _Switch(value: value, label: label),
                    ],
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

/// A macOS switch, 34×20, with the knob sliding on a spring-like curve.
class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.label});

  final bool value;
  final String label;

  static const _duration = Duration(milliseconds: 220);
  static const _curve = Cubic(0.23, 1, 0.32, 1);

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    return Semantics(
      toggled: value,
      label: label,
      child: AnimatedContainer(
        duration: _duration,
        curve: _curve,
        width: 34,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? p.colors.accent : p.off,
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedAlign(
          duration: _duration,
          curve: _curve,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A line of text with a button, for a problem the user can fix.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    required this.action,
    required this.onAction,
  });

  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: TextStyle(color: c.fg, height: 1.35)),
          ),
          const SizedBox(width: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onAction,
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.field,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  action,
                  style: TextStyle(color: c.fg, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
