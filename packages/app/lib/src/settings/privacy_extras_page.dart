import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../privacy/privacy_settings.dart';
import 'settings_style.dart';

/// Privacy extras: ghost mode and the switches it is made of, all off
/// until the user turns them on.
class PrivacyExtrasPage extends ConsumerWidget {
  const PrivacyExtrasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(privacySettingsProvider);
    final notifier = ref.read(privacySettingsProvider.notifier);
    void update(PrivacySettings Function(PrivacySettings) change) =>
        notifier.update(change);

    return SettingsPage(
      children: [
        SettingsGroup(
          footer: SettingsFooter(l10n.privacyExtrasAbout),
          children: [
            _SwitchRow(
              title: l10n.ghostMode,
              subtitle: l10n.ghostModeHint,
              value: settings.isGhost,
              onChanged: notifier.setGhost,
            ),
          ],
        ),
        SettingsGroup(
          footer: SettingsFooter(l10n.privacyExtrasOnlineNote),
          children: [
            _SwitchRow(
              title: l10n.hideReadReceipts,
              subtitle: l10n.hideReadReceiptsHint,
              value: settings.hideReadReceipts,
              onChanged: (on) =>
                  update((s) => s.copyWith(hideReadReceipts: on)),
            ),
            _SwitchRow(
              title: l10n.hideTyping,
              subtitle: l10n.hideTypingHint,
              value: settings.hideTyping,
              onChanged: (on) => update((s) => s.copyWith(hideTyping: on)),
            ),
            _SwitchRow(
              title: l10n.stayOffline,
              subtitle: l10n.stayOfflineHint,
              value: settings.stayOffline,
              onChanged: (on) => update((s) => s.copyWith(stayOffline: on)),
            ),
            _SwitchRow(
              title: l10n.hideContentOpened,
              subtitle: l10n.hideContentOpenedHint,
              value: settings.hideContentOpened,
              onChanged: (on) =>
                  update((s) => s.copyWith(hideContentOpened: on)),
            ),
          ],
        ),
      ],
    );
  }
}

/// A settings row that flips [value] when clicked anywhere on it.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    child: SettingsRow(
      title: title,
      subtitle: subtitle,
      trailing: _Switch(value: value),
      onTap: () => onChanged(!value),
    ),
  );
}

/// A macOS switch, 34×20, as on the notifications page.
class _Switch extends StatelessWidget {
  const _Switch({required this.value});

  final bool value;

  static const _duration = Duration(milliseconds: 220);
  static const _curve = Cubic(0.23, 1, 0.32, 1);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _duration;
    return AnimatedContainer(
      duration: duration,
      curve: _curve,
      width: 34,
      height: 20,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value
            ? c.accent
            : c.isDark
            ? const Color(0xFF48484C)
            : const Color(0xFFD9D9DE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: AnimatedAlign(
        duration: duration,
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
    );
  }
}
