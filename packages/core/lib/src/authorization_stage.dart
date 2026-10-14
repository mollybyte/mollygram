import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// How Telegram delivered the sign-in code.
enum CodeDelivery { app, sms, call, other }

enum AuthorizationStageKind {
  tdlibParameters,
  phoneNumber,
  qrCode,
  code,
  password,
  ready,

  /// TDLib is logging out or closing; the session has to be restarted.
  closing,
  unavailable,
}

/// The user-facing step represented by TDLib's authorization state.
///
/// The app reacts to [AuthorizationStage], rather than branching directly on
/// generated TDLib types throughout the UI.
sealed class AuthorizationStage {
  const AuthorizationStage();

  const factory AuthorizationStage.tdlibParameters() = _TdlibParameters;
  const factory AuthorizationStage.phoneNumber() = _PhoneNumber;
  const factory AuthorizationStage.qrCode({required String link}) = _QrCode;
  const factory AuthorizationStage.code({
    String phoneNumber,
    CodeDelivery delivery,
  }) = _Code;
  const factory AuthorizationStage.password({String hint}) = _Password;
  const factory AuthorizationStage.ready() = _Ready;
  const factory AuthorizationStage.closing() = _Closing;
  const factory AuthorizationStage.unavailable() = _Unavailable;

  AuthorizationStageKind get kind;

  /// A short-lived `tg://` link to render as a QR code, if TDLib supplied one.
  String? get qrLink => null;

  /// The number the code was sent to, while TDLib waits for the code.
  String get phoneNumber => '';

  /// Where the code went, while TDLib waits for the code.
  CodeDelivery get codeDelivery => CodeDelivery.other;

  /// The two-step verification hint; empty when the user set none.
  String get passwordHint => '';

  factory AuthorizationStage.from(td.AuthorizationState state) =>
      switch (state) {
        td.AuthorizationStateWaitTdlibParameters() =>
          const AuthorizationStage.tdlibParameters(),
        td.AuthorizationStateWaitPhoneNumber() =>
          const AuthorizationStage.phoneNumber(),
        td.AuthorizationStateWaitOtherDeviceConfirmation(link: final link) =>
          AuthorizationStage.qrCode(link: link),
        td.AuthorizationStateWaitCode(:final codeInfo) =>
          AuthorizationStage.code(
            phoneNumber: codeInfo.phoneNumber,
            delivery: switch (codeInfo.type) {
              td.AuthenticationCodeTypeTelegramMessage() => CodeDelivery.app,
              td.AuthenticationCodeTypeSms() ||
              td.AuthenticationCodeTypeSmsWord() ||
              td.AuthenticationCodeTypeSmsPhrase() => CodeDelivery.sms,
              td.AuthenticationCodeTypeCall() ||
              td.AuthenticationCodeTypeFlashCall() ||
              td.AuthenticationCodeTypeMissedCall() => CodeDelivery.call,
              _ => CodeDelivery.other,
            },
          ),
        td.AuthorizationStateWaitPassword(:final passwordHint) =>
          AuthorizationStage.password(hint: passwordHint),
        td.AuthorizationStateReady() => const AuthorizationStage.ready(),
        td.AuthorizationStateLoggingOut() ||
        td.AuthorizationStateClosing() ||
        td.AuthorizationStateClosed() => const AuthorizationStage.closing(),
        _ => const AuthorizationStage.unavailable(),
      };
}

final class _TdlibParameters extends AuthorizationStage {
  const _TdlibParameters();

  @override
  AuthorizationStageKind get kind => AuthorizationStageKind.tdlibParameters;
}

final class _PhoneNumber extends AuthorizationStage {
  const _PhoneNumber();

  @override
  AuthorizationStageKind get kind => AuthorizationStageKind.phoneNumber;
}

final class _QrCode extends AuthorizationStage {
  const _QrCode({required this.link});

  final String link;

  @override
  AuthorizationStageKind get kind => AuthorizationStageKind.qrCode;

  @override
  String get qrLink => link;
}

final class _Code extends AuthorizationStage {
  const _Code({this.phoneNumber = '', this.delivery = CodeDelivery.other});

  @override
  final String phoneNumber;
  final CodeDelivery delivery;

  @override
  CodeDelivery get codeDelivery => delivery;

  @override
  AuthorizationStageKind get kind => AuthorizationStageKind.code;
}

final class _Password extends AuthorizationStage {
  const _Password({this.hint = ''});

  final String hint;

  @override
  String get passwordHint => hint;

  @override
  AuthorizationStageKind get kind => AuthorizationStageKind.password;
}

final class _Ready extends AuthorizationStage {
  const _Ready();

  @override
  AuthorizationStageKind get kind => AuthorizationStageKind.ready;
}

final class _Closing extends AuthorizationStage {
  const _Closing();

  @override
  AuthorizationStageKind get kind => AuthorizationStageKind.closing;
}

final class _Unavailable extends AuthorizationStage {
  const _Unavailable();

  @override
  AuthorizationStageKind get kind => AuthorizationStageKind.unavailable;
}
