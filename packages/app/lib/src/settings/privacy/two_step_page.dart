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
  if (message.startsWith('PASSWORD_TOO_FRESH_')) {
    return l10n.twoStepPasswordTooFresh;
  }
  if (message.startsWith('SESSION_TOO_FRESH_')) {
    return l10n.twoStepSessionTooFresh;
  }
  if (message == 'NEW_PASSWORD_BAD' || message == 'NEW_SALT_INVALID') {
    return l10n.twoStepPasswordRejected;
  }
  if (error is TdException && error.code == 429) {
    return l10n.errorTooManyAttempts;
  }
  return l10n.saveFailed;
}

/// Two-step verification, after TelegramSwift's TwoStepVerification:
/// set a password with a hint and a recovery email, confirm the email
/// with its code, then change or remove them, or recover a forgotten
/// password through the email.
class TwoStepPage extends ConsumerStatefulWidget {
  const TwoStepPage({super.key});

  @override
  ConsumerState<TwoStepPage> createState() => _TwoStepPageState();
}

class _TwoStepPageState extends ConsumerState<TwoStepPage> {
  String? _notice;
  var _noticeIsError = false;

  PrivacySettingsController get _privacy => ref.read(privacyControllerProvider);

  /// The state the last request left, to go on to its email code.
  TwoStepState? _latest;

  /// Runs a request of a sheet: on success the page shows the new state
  /// and the notice [done] picks for it.
  Future<String?> Function(List<String>) _run(
    Future<TwoStepState> Function(List<String> values) request, {
    String? Function(List<String> values)? check,
    String? Function(TwoStepState state)? done,
  }) => (values) async {
    final l10n = AppLocalizations.of(context);
    if (check?.call(values) case final problem?) return problem;
    final TwoStepState state;
    try {
      state = await request(values);
    } on Object catch (error) {
      return twoStepError(l10n, error);
    }
    _latest = state;
    ref.invalidate(twoStepProvider);
    _show(done?.call(state));
    return null;
  };

  void _show(String? notice, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _notice = notice;
      _noticeIsError = error;
    });
  }

  /// After a new recovery email, the code it was sent goes in next.
  Future<void> _codeIfPending() async {
    if (_latest case final state? when state.awaitsEmailCode && mounted) {
      await _enterCode(state);
    }
  }

  /// "Forgot password?" under the sheets that ask for the password.
  FormSheetAside _forgotAside(TwoStepState state) => (
    label: AppLocalizations.of(context).twoStepForgotPassword,
    onTap: () => _forgot(state),
  );

  /// After TelegramSwift: with a recovery email, a code sent there sets a
  /// new password; without one, Telegram removes it after a wait.
  Future<void> _forgot(TwoStepState state) async {
    final l10n = AppLocalizations.of(context);
    if (!state.hasRecoveryEmail) {
      final confirmed = await showMgConfirm(
        context,
        title: l10n.twoStepResetTitle,
        message: l10n.twoStepResetMessage,
        confirmLabel: l10n.twoStepResetAction,
        cancelLabel: l10n.cancel,
        destructive: true,
      );
      if (confirmed == null || !mounted) return;
      try {
        final reset = await _privacy.resetPassword();
        ref.invalidate(twoStepProvider);
        switch (reset) {
          case PasswordResetDone():
            _show(l10n.twoStepTurnedOff);
          case PasswordResetPending(:final date):
            _show(l10n.twoStepResetPending(date));
          case PasswordResetDeclined(:final retryDate):
            _show(l10n.twoStepResetDeclined(retryDate), error: true);
        }
      } on Object catch (error) {
        _show(twoStepError(l10n, error), error: true);
      }
      return;
    }
    final String pattern;
    try {
      pattern = await _privacy.requestPasswordRecovery();
    } on Object catch (error) {
      _show(twoStepError(l10n, error), error: true);
      return;
    }
    if (!mounted) return;
    await showFormSheet(
      context,
      title: l10n.twoStepRecoverTitle,
      subtitle: l10n.twoStepRecoverAbout(pattern),
      fields: [
        FormSheetField(l10n.twoStepCode, keyboardType: TextInputType.number),
        FormSheetField(l10n.twoStepNewPassword, obscure: true),
        FormSheetField(l10n.twoStepRepeatPassword, obscure: true),
        FormSheetField(l10n.twoStepHint, optional: true),
      ],
      action: l10n.save,
      onSubmit: _run(
        check: (v) {
          if (v[3].trim() == v[1] && v[1].isNotEmpty) {
            return l10n.twoStepHintIsPassword;
          }
          return _matches(v[1], v[2]);
        },
        (v) =>
            _privacy.recoverPassword(code: v[0], newPassword: v[1], hint: v[3]),
        done: (_) => l10n.twoStepPasswordChanged,
      ),
    );
  }

  String? _matches(String a, String b) =>
      a == b ? null : AppLocalizations.of(context).passwordsDontMatch;

  Future<void> _setPassword(TwoStepState state, {required bool change}) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showFormSheet(
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
      aside: change && state.hasPassword ? _forgotAside(state) : null,
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
        // With a new email TDLib keeps the password until its code is in.
        done: (state) => state.awaitsEmailCode && !state.hasPassword
            ? l10n.twoStepConfirmToFinish
            : change
            ? l10n.twoStepPasswordChanged
            : l10n.twoStepPasswordSet,
      ),
    );
    if (saved) await _codeIfPending();
  }

  Future<void> _setEmail(TwoStepState state) async {
    final l10n = AppLocalizations.of(context);
    final hasEmail = state.hasRecoveryEmail;
    final saved = await showFormSheet(
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
      aside: _forgotAside(state),
      onSubmit: _run((v) => _privacy.setRecoveryEmail(v[0], v[1])),
    );
    if (saved) await _codeIfPending();
  }

  Future<void> _enterCode(TwoStepState state) async {
    final l10n = AppLocalizations.of(context);
    await showFormSheet(
      context,
      title: l10n.twoStepConfirmEmail,
      subtitle: l10n.twoStepCodeSent(state.pendingEmailPattern ?? ''),
      fields: [
        FormSheetField(
          l10n.twoStepCode,
          keyboardType: TextInputType.number,
          submitAtLength: state.codeLength,
        ),
      ],
      action: l10n.twoStepCheckCode,
      onSubmit: _run(
        (v) => _privacy.checkEmailCode(v[0]),
        done: (_) => l10n.twoStepEmailConfirmed,
      ),
    );
  }

  Future<void> _turnOff(TwoStepState state) async {
    final l10n = AppLocalizations.of(context);
    await showFormSheet(
      context,
      title: l10n.twoStepTurnOff,
      subtitle: l10n.twoStepTurnOffAbout,
      fields: [FormSheetField(l10n.twoStepCurrentPassword, obscure: true)],
      action: l10n.twoStepTurnOffAction,
      destructive: true,
      aside: _forgotAside(state),
      onSubmit: _run(
        (v) => _privacy.removePassword(v[0]),
        done: (_) => l10n.twoStepTurnedOff,
      ),
    );
  }

  Future<void> _simple(Future<TwoStepState> Function() request) async {
    final error = await _run((_) => request())(const []);
    if (error != null) _show(error, error: true);
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
            state.hasPassword
                ? l10n.twoStepOnAbout
                : state.awaitsEmailCode
                ? l10n.twoStepPendingAbout
                : l10n.twoStepOffAbout,
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
        if (state.pendingResetDate case final date?)
          SettingsGroup(
            footer: SettingsFooter(l10n.twoStepResetPending(date)),
            children: [
              SettingsRow(
                key: const ValueKey('cancelReset'),
                title: l10n.twoStepCancelReset,
                onTap: () => unawaited(_simple(_privacy.cancelPasswordReset)),
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
                    onTap: () => unawaited(_setPassword(state, change: true)),
                  ),
                  SettingsRow(
                    key: const ValueKey('email'),
                    title: state.hasRecoveryEmail
                        ? l10n.twoStepChangeEmail
                        : l10n.twoStepSetEmail,
                    chevron: true,
                    onTap: () => unawaited(_setEmail(state)),
                  ),
                  SettingsRow(
                    key: const ValueKey('turnOff'),
                    title: l10n.twoStepTurnOff,
                    destructive: true,
                    onTap: () => unawaited(_turnOff(state)),
                  ),
                ]
              : [
                  SettingsRow(
                    key: const ValueKey('setPassword'),
                    title: l10n.twoStepSetPassword,
                    chevron: true,
                    onTap: () => unawaited(_setPassword(state, change: false)),
                  ),
                ],
        ),
      ],
    );
  }
}
