import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../privacy/message_store.dart';
import '../privacy/privacy_settings.dart';
import 'settings_style.dart';
import 'storage_page.dart' show formatBytes;

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
        // Risky, so on its own, with the warning in the footer once on.
        SettingsGroup(
          key: const ValueKey('secretScreenshots'),
          footer: settings.allowSecretScreenshots
              ? SettingsFooter(l10n.allowSecretScreenshotsHint, error: true)
              : null,
          children: [
            _SwitchRow(
              title: l10n.allowSecretScreenshots,
              subtitle: l10n.secretScreenshotsOff,
              value: settings.allowSecretScreenshots,
              onChanged: (on) =>
                  update((s) => s.copyWith(allowSecretScreenshots: on)),
            ),
          ],
        ),
        SettingsGroup(
          footer: SettingsFooter(l10n.storedMessagesAbout),
          children: [
            _SwitchRow(
              title: l10n.keepDeletedMessages,
              subtitle: l10n.keepDeletedMessagesHint,
              value: settings.keepDeletedMessages,
              onChanged: (on) =>
                  update((s) => s.copyWith(keepDeletedMessages: on)),
            ),
            _SwitchRow(
              title: l10n.keepEditHistory,
              subtitle: l10n.keepEditHistoryHint,
              value: settings.keepEditHistory,
              onChanged: (on) => update((s) => s.copyWith(keepEditHistory: on)),
            ),
            const _StoredDataRow(),
          ],
        ),
      ],
    );
  }
}

/// The stored data's size with "Clear", after a confirmation; when its
/// key is lost, "Reset" instead.
class _StoredDataRow extends ConsumerWidget implements SettingsGroupRow {
  const _StoredDataRow();

  Future<void> _run(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String label,
    required Future<void> Function() action,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: title,
      confirmLabel: label,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    // Null when cancelled; otherwise the (unused) option's value.
    if (confirmed == null) return;
    await action();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final status = ref.watch(storedMessagesStatusProvider).value;
    if (status != null && status.unreadable) {
      return SettingsRow(
        key: const ValueKey('storedDataUnreadable'),
        title: l10n.storedDataUnreadable,
        subtitle: l10n.storedDataUnreadableHint,
        trailing: SettingsButton(
          key: const ValueKey('resetStoredData'),
          label: l10n.resetStoredData,
          destructive: true,
          onPressed: () => _run(
            context,
            ref,
            title: l10n.resetStoredDataTitle,
            label: l10n.resetStoredData,
            action: ref.read(resetStoredMessagesProvider),
          ),
        ),
      );
    }
    return SettingsRow(
      key: const ValueKey('storedData'),
      title: l10n.clearStoredData,
      subtitle: status == null ? null : formatBytes(status.size, l10n, locale),
      trailing: SettingsButton(
        key: const ValueKey('clearStoredData'),
        label: l10n.clear,
        destructive: true,
        onPressed: status == null || status.count == 0
            ? null
            : () => _run(
                context,
                ref,
                title: l10n.clearStoredDataTitle,
                label: l10n.clear,
                action: ref.read(clearStoredMessagesProvider),
              ),
      ),
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
