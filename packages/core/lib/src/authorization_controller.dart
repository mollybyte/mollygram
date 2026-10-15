import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'authorization_stage.dart';
import 'phone_country.dart';

/// Coordinates TDLib's authorization requests with the application UI.
///
/// It deliberately owns no API credentials or local paths. Those are supplied
/// only when TDLib asks for its parameters, so this controller remains usable
/// for phone, QR, code, and two-step verification flows.
final class AuthorizationController {
  AuthorizationController(this._client);

  final td.TdClient _client;
  final _stages = StreamController<AuthorizationStage>.broadcast(sync: true);
  final _closed = Completer<void>();
  StreamSubscription<td.TdObject>? _subscription;
  AuthorizationStage? _currentStage;

  /// The current and subsequent user-facing authorization stages.
  Stream<AuthorizationStage> get stages => _stages.stream;

  /// The latest stage received from TDLib, if [start] has completed.
  AuthorizationStage? get currentStage => _currentStage;

  /// Completes when TDLib reports this client closed.
  Future<void> get closed => _closed.future;

  /// Whether this app asked TDLib to log out. A close it didn't ask for
  /// comes from elsewhere, such as the session being terminated on another
  /// device.
  bool get logOutRequested => _logOutRequested;
  var _logOutRequested = false;

  /// Starts observing TDLib and publishes its current authorization state.
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _client.updates.listen(_onUpdate);
    final state = await _client.send(const td.GetAuthorizationState());
    _publish(state);
  }

  Future<void> submitPhone(String phoneNumber) =>
      _client.send(td.SetAuthenticationPhoneNumber(phoneNumber: phoneNumber));

  Future<void> requestQrCode() =>
      _client.send(const td.RequestQrCodeAuthentication(otherUserIds: []));

  /// Leaves the QR code step so the user can sign in by phone number.
  ///
  /// TDLib has no way back from `authorizationStateWaitOtherDeviceConfirmation`
  /// to the phone number step: `setAuthenticationPhoneNumber` is rejected
  /// there. The only exit is `logOut`, which drops the unfinished
  /// authorization and closes this client. The caller then starts a new
  /// session, which begins at the phone number step.
  ///
  /// Completes once TDLib reports the client closed, or after [timeout]:
  /// nothing of value is lost here, so a slow close is not an error.
  Future<void> abandonQrCode({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      await logOut(timeout: timeout);
    } on TimeoutException {
      // Best effort: the caller starts a new session either way.
    }
  }

  /// Signs out of the account. TDLib then closes this client and deletes
  /// the local data; the caller starts a new session for the next sign-in.
  ///
  /// Completes once TDLib reports the client closed. Throws a
  /// [TimeoutException] when it has not closed within [timeout]: the
  /// account may still be signed in, so the caller must not drop it.
  Future<void> logOut({Duration timeout = const Duration(seconds: 10)}) async {
    _logOutRequested = true;
    try {
      await _client.send(const td.LogOut());
    } on td.TdClientClosed {
      return;
    } on td.TdException {
      // Still signed in: a close from now on was not asked for here.
      _logOutRequested = false;
      rethrow;
    }
    await _closed.future.timeout(timeout);
  }

  Future<void> submitCode(String code) =>
      _client.send(td.CheckAuthenticationCode(code: code));

  Future<void> submitPassword(String password) =>
      _client.send(td.CheckAuthenticationPassword(password: password));

  /// Countries for the phone number form, sorted by name, hidden ones left
  /// out.
  Future<List<PhoneCountry>> countries() async {
    final result = await _client.send(const td.GetCountries());
    return [
      for (final country in result.countries)
        if (!country.isHidden)
          PhoneCountry(
            code: country.countryCode,
            name: country.name,
            englishName: country.englishName,
            callingCodes: country.callingCodes,
          ),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// The user's country guessed by Telegram from the IP address.
  Future<String> currentCountryCode() async =>
      (await _client.send(const td.GetCountryCode())).text;

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _stages.close();
  }

  void _onUpdate(td.TdObject update) {
    if (update is td.UpdateAuthorizationState) {
      _publish(update.authorizationState);
    }
  }

  void _publish(td.TdObject object) {
    if (object is td.AuthorizationState) {
      if (object is td.AuthorizationStateClosed && !_closed.isCompleted) {
        _closed.complete();
      }
      final stage = AuthorizationStage.from(object);
      _currentStage = stage;
      _stages.add(stage);
    }
  }
}
