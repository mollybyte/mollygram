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
      trailing: ExcludeSemantics(child: MgSwitch(value: value)),
      onTap: () => onChanged(!value),
    ),
  );
}
