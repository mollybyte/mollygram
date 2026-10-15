import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' show TdException;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../settings_style.dart';
import 'form_sheet.dart';
import 'privacy_providers.dart';

/// Two-step verification as the Privacy and security row shows it.
final twoStepProvider = FutureProvider.autoDispose<TwoStepState>(
  (ref) => ref.watch(privacyControllerProvider).twoStep(),
);

/// What a failed two-step request means, in words.
String twoStepError(AppLocalizations l10n, Object error) {
  final message = error is TdException ? error.message : '';
  if (message == 'PASSWORD_HASH_INVALID') return l10n.errorInvalidPassword;
  if (message.startsWith('EMAIL_INVALID')) return l10n.twoStepEmailInvalid;
  if (message.contains('CODE_INVALID')) return l10n.errorInvalidCode;
  if (message.startsWith('PASSWORD_') || message == 'NEW_PASSWORD_BAD') {
    return l10n.twoStepPasswordRejected;
  }
  if (error is TdException && error.code == 429) {
    return l10n.errorTooManyAttempts;
  }
  return l10n.saveFailed;
}

/// Two-step verification, after TelegramSwift's TwoStepVerification:
/// set a password with a hint and a recovery email, confirm the email
/// with its code, then change or remove them.
class TwoStepPage extends ConsumerStatefulWidget {
  const TwoStepPage({super.key});

  @override
  ConsumerState<TwoStepPage> createState() => _TwoStepPageState();
}

class _TwoStepPageState extends ConsumerState<TwoStepPage> {
  String? _notice;
  var _noticeIsError = false;

  PrivacySettingsController get _privacy => ref.read(privacyControllerProvider);

  /// Runs a request of a sheet: on success the page shows the new state.
  Future<String?> Function(List<String>) _run(
    Future<TwoStepState> Function(List<String> values) request, {
    String? Function(List<String> values)? check,
    String? done,
  }) => (values) async {
    final l10n = AppLocalizations.of(context);
    if (check?.call(values) case final problem?) return problem;
    try {
      await request(values);
    } on Object catch (error) {
      return twoStepError(l10n, error);
    }
    ref.invalidate(twoStepProvider);
    if (mounted) {
      setState(() {
        _notice = done;
        _noticeIsError = false;
      });
    }
    return null;
  };

  String? _matches(String a, String b) =>
      a == b ? null : AppLocalizations.of(context).passwordsDontMatch;

  Future<void> _setPassword({required bool change}) async {
    final l10n = AppLocalizations.of(context);
    await showFormSheet(
      context,
      title: change ? l10n.twoStepChangePassword : l10n.twoStepSetPassword,
      subtitle: change ? null : l10n.twoStepSetPasswordAbout,
      fields: [
        if (change) FormSheetField(l10n.twoStepCurrentPassword, obscure: true),
        FormSheetField(l10n.twoStepNewPassword, obscure: true),
        FormSheetField(l10n.twoStepRepeatPassword, obscure: true),
        FormSheetField(l10n.twoStepHint, optional: true),
        if (!change)
          FormSheetField(
            l10n.twoStepRecoveryEmail,
            optional: true,
            keyboardType: TextInputType.emailAddress,
          ),
      ],
      action: l10n.save,
      onSubmit: _run(
        check: (v) {
          final at = change ? 1 : 0;
          if (v[at + 2].trim() == v[at] && v[at].isNotEmpty) {
            return l10n.twoStepHintIsPassword;
          }
          return _matches(v[at], v[at + 1]);
        },
        (v) {
          final at = change ? 1 : 0;
          final email = change ? '' : v[at + 3].trim();
          return _privacy.setPassword(
            oldPassword: change ? v[0] : '',
            newPassword: v[at],
            hint: v[at + 2],
            email: email.isEmpty ? null : email,
          );
        },
        done: change ? l10n.twoStepPasswordChanged : l10n.twoStepPasswordSet,
      ),
    );
  }

  Future<void> _setEmail(bool hasEmail) async {
    final l10n = AppLocalizations.of(context);
    await showFormSheet(
      context,
      title: hasEmail ? l10n.twoStepChangeEmail : l10n.twoStepSetEmail,
      subtitle: l10n.twoStepRecoveryEmailAbout,
      fields: [
        FormSheetField(l10n.twoStepCurrentPassword, obscure: true),
        FormSheetField(
          l10n.twoStepRecoveryEmail,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
      action: l10n.save,
      onSubmit: _run((v) => _privacy.setRecoveryEmail(v[0], v[1])),
    );
  }

  Future<void> _enterCode(TwoStepState state) async {
    final l10n = AppLocalizations.of(context);
    await showFormSheet(
      context,
      title: l10n.twoStepConfirmEmail,
      subtitle: l10n.twoStepCodeSent(state.pendingEmailPattern ?? ''),
      fields: [
        FormSheetField(l10n.twoStepCode, keyboardType: TextInputType.number),
      ],
      action: l10n.twoStepCheckCode,
      onSubmit: _run(
        (v) => _privacy.checkEmailCode(v[0]),
        done: l10n.twoStepEmailConfirmed,
      ),
    );
  }

  Future<void> _turnOff() async {
    final l10n = AppLocalizations.of(context);
    await showFormSheet(
      context,
      title: l10n.twoStepTurnOff,
      subtitle: l10n.twoStepTurnOffAbout,
      fields: [FormSheetField(l10n.twoStepCurrentPassword, obscure: true)],
      action: l10n.twoStepTurnOffAction,
      destructive: true,
      onSubmit: _run(
        (v) => _privacy.removePassword(v[0]),
        done: l10n.twoStepTurnedOff,
      ),
    );
  }

  Future<void> _simple(Future<TwoStepState> Function() request) async {
    final error = await _run((_) => request())(const []);
    if (error != null && mounted) {
      setState(() {
        _notice = error;
        _noticeIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loaded = ref.watch(twoStepProvider);
    final state = loaded.value;
    if (state == null) {
      return loaded.hasError
          ? SettingsPage(
              children: [SettingsFooter(l10n.twoStepLoadFailed, error: true)],
            )
          : const Center(child: SettingsSpinner());
    }
    final notice = _notice;
    final footer = notice != null
        ? SettingsFooter(
            notice,
            error: _noticeIsError,
            success: !_noticeIsError,
          )
        : null;
    return SettingsPage(
      children: [
        SettingsGroup(
          footer: SettingsFooter(
            state.hasPassword ? l10n.twoStepOnAbout : l10n.twoStepOffAbout,
          ),
          children: [
            SettingsRow(
              title: l10n.twoStep,
              trailing: Text(
                state.hasPassword ? l10n.twoStepOn : l10n.twoStepOff,
                style: mgTextStyle(
                  MgColors.of(context),
                  color: MgColors.of(context).fg2,
                ),
              ),
            ),
          ],
        ),
        if (state.awaitsEmailCode)
          SettingsGroup(
            title: l10n.twoStepConfirmEmail,
            footer: SettingsFooter(
              l10n.twoStepCodeSent(state.pendingEmailPattern ?? ''),
            ),
            children: [
              SettingsRow(
                key: const ValueKey('enterCode'),
                title: l10n.twoStepEnterCode,
                chevron: true,
                onTap: () => unawaited(_enterCode(state)),
              ),
              SettingsRow(
                title: l10n.twoStepResendCode,
                onTap: () => unawaited(_simple(_privacy.resendEmailCode)),
              ),
              SettingsRow(
                title: l10n.twoStepCancelEmail,
                destructive: true,
                onTap: () => unawaited(_simple(_privacy.cancelEmailCode)),
              ),
            ],
          ),
        SettingsGroup(
          footer: footer,
          children: state.hasPassword
              ? [
                  SettingsRow(
                    key: const ValueKey('changePassword'),
                    title: l10n.twoStepChangePassword,
                    subtitle: state.hint.isEmpty
                        ? null
                        : l10n.twoStepHintIs(state.hint),
                    chevron: true,
                    onTap: () => unawaited(_setPassword(change: true)),
                  ),
                  SettingsRow(
                    key: const ValueKey('email'),
                    title: state.hasRecoveryEmail
                        ? l10n.twoStepChangeEmail
                        : l10n.twoStepSetEmail,
                    chevron: true,
                    onTap: () => unawaited(_setEmail(state.hasRecoveryEmail)),
                  ),
                  SettingsRow(
                    key: const ValueKey('turnOff'),
                    title: l10n.twoStepTurnOff,
                    destructive: true,
                    onTap: () => unawaited(_turnOff()),
                  ),
                ]
              : [
                  SettingsRow(
                    key: const ValueKey('setPassword'),
                    title: l10n.twoStepSetPassword,
                    chevron: true,
                    onTap: () => unawaited(_setPassword(change: false)),
                  ),
                ],
        ),
      ],
    );
  }
}
