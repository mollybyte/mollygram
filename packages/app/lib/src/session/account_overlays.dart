import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../settings/settings_style.dart';
import 'accounts.dart';

/// Over sign-in or a failed start: "Back to …" when another signed-in
/// account can be opened instead.
class AccountBackButton extends ConsumerWidget {
  const AccountBackButton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(accountsProvider).value;
    final notifier = ref.read(accountsProvider.notifier);
    final target = index?.accounts
        .where((a) => a.slot == notifier.backTarget)
        .firstOrNull;
    if (index == null || target == null) return child;
    final l10n = AppLocalizations.of(context);
    final number = index.accounts.indexOf(target) + 1;
    final busy = ref.watch(accountsActivityProvider) != null;
    return Stack(
      children: [
        child,
        Positioned(
          top: 40,
          right: 20,
          child: SettingsButton(
            key: const ValueKey('backToAccount'),
            label: l10n.backToAccount(accountTitle(target, l10n, number)),
            onPressed: busy ? null : () => unawaited(notifier.back()),
          ),
        ),
      ],
    );
  }
}

/// Covers the window while an account logs out (another account may be
/// opened for it meanwhile), and offers to drop an account signed in
/// twice.
class AccountsLayer extends ConsumerWidget {
  const AccountsLayer({super.key, required this.child});

  final Widget child;

  Future<void> _offerSwitch(
    BuildContext context,
    WidgetRef ref,
    DuplicateAccount duplicate,
  ) async {
    final l10n = AppLocalizations.of(context);
    final index = ref.read(accountsProvider).value;
    final existing = index?.accounts
        .where((a) => a.slot == duplicate.existing)
        .firstOrNull;
    if (index == null || existing == null) return;
    final title = accountTitle(
      existing,
      l10n,
      index.accounts.indexOf(existing) + 1,
    );
    final confirmed = await showMgConfirm(
      context,
      title: l10n.duplicateAccountTitle(title),
      message: l10n.duplicateAccountMessage,
      confirmLabel: l10n.switchAccount,
      cancelLabel: l10n.cancel,
    );
    if (confirmed == null) {
      ref.read(duplicateAccountProvider.notifier).set(null);
      return;
    }
    await ref.read(accountsProvider.notifier).resolveDuplicate();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(duplicateAccountProvider, (_, next) {
      if (next != null) unawaited(_offerSwitch(context, ref, next));
    });
    final c = MgColors.of(context);
    final loggingOut =
        ref.watch(accountsActivityProvider) == AccountsActivity.loggingOut;
    return Stack(
      children: [
        child,
        if (loggingOut)
          Positioned.fill(
            key: const ValueKey('loggingOut'),
            child: ColoredBox(
              color: c.windowBackground,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SettingsSpinner(size: 18),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).loggingOut,
                      style: mgTextStyle(c, color: c.fg2),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
