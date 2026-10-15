import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../settings_style.dart';
import 'form_sheet.dart';
import 'passcode.dart';
import 'user_picker.dart' show checkIcon;

/// The passcode lock, after TelegramSwift's PasscodeSettings: turn it on
/// or off, change it, and how long the user may be away before the window
/// locks.
class PasscodePage extends ConsumerStatefulWidget {
  const PasscodePage({super.key});

  @override
  ConsumerState<PasscodePage> createState() => _PasscodePageState();
}

class _PasscodePageState extends ConsumerState<PasscodePage> {
  /// A failed auto-lock change.
  String? _error;

  Future<void> _setAutoLock(int minutes) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    try {
      await ref.read(passcodeLockProvider.notifier).setAutoLock(minutes);
    } on Object {
      if (mounted) setState(() => _error = l10n.saveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final lock = ref.watch(passcodeLockProvider);
    final notifier = ref.read(passcodeLockProvider.notifier);
    final settings = lock.settings;

    String? Function(List<String>) newPasscode(int at) => (v) {
      if (v[at].length < 4) return l10n.passcodeTooShort;
      if (v[at] != v[at + 1]) return l10n.passcodesDontMatch;
      return null;
    };

    /// Runs a keychain change, saying when it couldn't be written.
    Future<String?> saving(Future<void> Function() change) async {
      try {
        await change();
        return null;
      } on Object {
        return l10n.saveFailed;
      }
    }

    Future<String?> Function(List<String>) checked(
      Future<String?> Function(List<String>) then,
    ) => (v) async {
      if (!await notifier.verify(v[0])) return l10n.passcodeWrong;
      return then(v);
    };

    Future<void> turnOn() => showFormSheet(
      context,
      title: l10n.passcodeTurnOn,
      subtitle: l10n.passcodeAbout,
      fields: [
        FormSheetField(l10n.passcodeNew, obscure: true),
        FormSheetField(l10n.passcodeRepeat, obscure: true),
      ],
      action: l10n.save,
      onSubmit: (v) async {
        if (newPasscode(0)(v) case final problem?) return problem;
        return saving(() => notifier.setPasscode(v[0]));
      },
    );

    Future<void> change() => showFormSheet(
      context,
      title: l10n.passcodeChange,
      fields: [
        FormSheetField(l10n.passcodeCurrent, obscure: true),
        FormSheetField(l10n.passcodeNew, obscure: true),
        FormSheetField(l10n.passcodeRepeat, obscure: true),
      ],
      action: l10n.save,
      onSubmit: checked((v) async {
        if (newPasscode(1)(v) case final problem?) return problem;
        return saving(() => notifier.setPasscode(v[1]));
      }),
    );

    Future<void> turnOff() => showFormSheet(
      context,
      title: l10n.passcodeTurnOff,
      fields: [FormSheetField(l10n.passcodeCurrent, obscure: true)],
      action: l10n.passcodeTurnOffAction,
      destructive: true,
      onSubmit: checked((_) => saving(notifier.turnOff)),
    );

    return SettingsPage(
      children: [
        SettingsGroup(
          footer: SettingsFooter(l10n.passcodeAbout),
          children: settings.enabled
              ? [
                  SettingsRow(
                    key: const ValueKey('passcodeChange'),
                    title: l10n.passcodeChange,
                    chevron: true,
                    onTap: () => unawaited(change()),
                  ),
                  SettingsRow(
                    key: const ValueKey('passcodeOff'),
                    title: l10n.passcodeTurnOff,
                    destructive: true,
                    onTap: () => unawaited(turnOff()),
                  ),
                ]
              : [
                  SettingsRow(
                    key: const ValueKey('passcodeOn'),
                    title: l10n.passcodeTurnOn,
                    chevron: true,
                    onTap: () => unawaited(turnOn()),
                  ),
                ],
        ),
        AnimatedSize(
          duration: settingsMotionOf(context),
          curve: settingsCurve,
          alignment: Alignment.topCenter,
          child: settings.enabled
              ? SettingsGroup(
                  title: l10n.passcodeAutoLock,
                  footer: SettingsFooter(
                    _error ?? l10n.passcodeLockNowHint,
                    error: _error != null,
                  ),
                  children: [
                    for (final minutes in PasscodeSettings.autoLockChoices)
                      Semantics(
                        selected: minutes == settings.autoLockMinutes,
                        child: SettingsRow(
                          key: ValueKey(('autoLock', minutes)),
                          title: minutes == 60
                              ? l10n.passcodeAwayHour
                              : l10n.passcodeAwayFor(minutes),
                          trailing: AnimatedOpacity(
                            duration: settingsMotionOf(context),
                            opacity: minutes == settings.autoLockMinutes
                                ? 1
                                : 0,
                            child: MgIcon(
                              checkIcon,
                              size: 15,
                              stroke: 2.3,
                              color: c.accent,
                            ),
                          ),
                          onTap: () => unawaited(_setAutoLock(minutes)),
                        ),
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
