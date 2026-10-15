import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../settings_style.dart';
import 'privacy_providers.dart';
import 'user_picker.dart' show checkIcon;

/// Days the account may go unused before Telegram deletes it.
final accountTtlProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(privacyControllerProvider).accountTtl(),
);

/// "6 months" for 180 days, as TelegramSwift names them; another period
/// Telegram set reads in days.
String accountTtlLabel(AppLocalizations l10n, int days) => switch (days) {
  30 || 90 || 180 => l10n.ttlMonths(days ~/ 30),
  365 => l10n.ttlYears(1),
  548 => l10n.ttlMonths(18),
  730 => l10n.ttlMonths(24),
  _ => l10n.ttlDays(days),
};

/// "Delete my account if away for", after TelegramSwift's choice of one,
/// three, six or twelve months. A click saves at once.
class AccountTtlPage extends ConsumerStatefulWidget {
  const AccountTtlPage({super.key});

  @override
  ConsumerState<AccountTtlPage> createState() => _AccountTtlPageState();
}

class _AccountTtlPageState extends ConsumerState<AccountTtlPage> {
  int? _pending;
  String? _error;

  Future<void> _choose(int days) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _pending = days;
      _error = null;
    });
    try {
      await ref.read(privacyControllerProvider).setAccountTtl(days);
      ref.invalidate(accountTtlProvider);
    } on Object {
      if (mounted) setState(() => _error = l10n.saveFailed);
    }
    if (mounted) setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final loaded = ref.watch(accountTtlProvider);
    final current = _pending ?? loaded.value;
    if (current == null) {
      return loaded.hasError
          ? SettingsPage(
              children: [SettingsFooter(l10n.privacyLoadFailed, error: true)],
            )
          : const Center(child: SettingsSpinner());
    }
    return SettingsPage(
      children: [
        SettingsGroup(
          title: l10n.accountTtlQuestion,
          footer: SettingsFooter(
            _error ?? l10n.accountTtlAbout,
            error: _error != null,
          ),
          children: [
            for (final days in {...accountTtlChoices, current})
              Semantics(
                selected: days == current,
                child: SettingsRow(
                  key: ValueKey(('ttl', days)),
                  title: accountTtlLabel(l10n, days),
                  trailing: AnimatedOpacity(
                    duration: settingsMotionOf(context),
                    opacity: days == current ? 1 : 0,
                    child: MgIcon(
                      checkIcon,
                      size: 15,
                      stroke: 2.3,
                      color: c.accent,
                    ),
                  ),
                  onTap: days == current
                      ? null
                      : () => unawaited(_choose(days)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
