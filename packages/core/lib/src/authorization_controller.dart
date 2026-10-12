import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'authorization_stage.dart';

/// Coordinates TDLib's authorization requests with the application UI.
///
/// It deliberately owns no API credentials or local paths. Those are supplied
/// only when TDLib asks for its parameters, so this controller remains usable
/// for phone, QR, code, and two-step verification flows.
final class AuthorizationController {
  AuthorizationController(this._client);

  final td.TdClient _client;
  final _stages = StreamController<AuthorizationStage>.broadcast(sync: true);
  StreamSubscription<td.TdObject>? _subscription;

  /// The current and subsequent user-facing authorization stages.
  Stream<AuthorizationStage> get stages => _stages.stream;

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

  Future<void> submitCode(String code) =>
      _client.send(td.CheckAuthenticationCode(code: code));

  Future<void> submitPassword(String password) =>
      _client.send(td.CheckAuthenticationPassword(password: password));

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
      _stages.add(AuthorizationStage.from(object));
    }
  }
}
