import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

enum AuthorizationStageKind {
  tdlibParameters,
  phoneNumber,
  qrCode,
  code,
  password,
  ready,
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
  const factory AuthorizationStage.code() = _Code;
  const factory AuthorizationStage.password({String hint}) = _Password;
  const factory AuthorizationStage.ready() = _Ready;
  const factory AuthorizationStage.unavailable() = _Unavailable;

  AuthorizationStageKind get kind;

  /// A short-lived `tg://` link to render as a QR code, if TDLib supplied one.
  String? get qrLink => null;

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
        td.AuthorizationStateWaitCode() => const AuthorizationStage.code(),
        td.AuthorizationStateWaitPassword(:final passwordHint) =>
          AuthorizationStage.password(hint: passwordHint),
        td.AuthorizationStateReady() => const AuthorizationStage.ready(),
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
  const _Code();

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

final class _Unavailable extends AuthorizationStage {
  const _Unavailable();

  @override
  AuthorizationStageKind get kind => AuthorizationStageKind.unavailable;
}
