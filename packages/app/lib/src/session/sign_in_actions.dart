import 'package:mollygram_core/mollygram_core.dart';

/// The requests the sign-in screen can make. Each one completes with an
/// error from TDLib when the input is rejected.
abstract interface class SignInActions {
  Future<void> submitPhone(String phoneNumber);
  Future<void> requestQrCode();
  Future<void> submitCode(String code);
  Future<void> submitPassword(String password);

  /// Countries for the phone form, sorted by name.
  Future<List<PhoneCountry>> countries();

  /// The user's country code guessed from the IP address.
  Future<String> currentCountryCode();
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

  @override
  Future<List<PhoneCountry>> countries() => _controller.countries();

  @override
  Future<String> currentCountryCode() => _controller.currentCountryCode();
}
