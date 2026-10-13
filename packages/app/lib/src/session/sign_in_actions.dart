import 'package:mollygram_core/mollygram_core.dart';

/// The requests the sign-in screen can make. Each one completes with an
/// error from TDLib when the input is rejected.
abstract interface class SignInActions {
  Future<void> submitPhone(String phoneNumber);
  Future<void> requestQrCode();
  Future<void> submitCode(String code);
  Future<void> submitPassword(String password);
}

final class SessionSignInActions implements SignInActions {
  const SessionSignInActions(this._controller);

  final AuthorizationController _controller;

  @override
  Future<void> submitPhone(String phoneNumber) =>
      _controller.submitPhone(phoneNumber);

  @override
  Future<void> requestQrCode() => _controller.requestQrCode();

  @override
  Future<void> submitCode(String code) => _controller.submitCode(code);

  @override
  Future<void> submitPassword(String password) =>
      _controller.submitPassword(password);
}
