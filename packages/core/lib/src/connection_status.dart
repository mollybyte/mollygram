import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// How the account's connection to Telegram is doing, from
/// `updateConnectionState`.
enum ConnectionStatus {
  /// The system reports no network.
  waitingForNetwork,

  /// Establishing a connection with the proxy server.
  connectingToProxy,

  /// Establishing a connection with the Telegram servers.
  connecting,

  /// Connected, receiving what happened while the app was offline.
  updating,

  /// Connected and up to date.
  ready;

  bool get isReady => this == ready;

  static ConnectionStatus from(td.ConnectionState state) => switch (state) {
    td.ConnectionStateWaitingForNetwork() => waitingForNetwork,
    td.ConnectionStateConnectingToProxy() => connectingToProxy,
    td.ConnectionStateConnecting() => connecting,
    td.ConnectionStateUpdating() => updating,
    td.ConnectionStateReady() => ready,
  };
}

/// Follows the connection state TDLib reports for one client.
///
/// TDLib sends the state only when it changes, so [current] starts as
/// [ConnectionStatus.ready] until the first update: the UI shows nothing
/// rather than a state it hasn't been told about.
final class ConnectionMonitor {
  ConnectionMonitor(this._client);

  final td.TdClient _client;
  final _changes = StreamController<ConnectionStatus>.broadcast(sync: true);
  StreamSubscription<td.TdObject>? _subscription;
  var _current = ConnectionStatus.ready;

  ConnectionStatus get current => _current;

  /// Each new status; repeats of the same status are left out.
  Stream<ConnectionStatus> get changes => _changes.stream;

  Future<void> start() async {
    _subscription ??= _client.updates.listen((update) {
      if (update is! td.UpdateConnectionState) return;
      final status = ConnectionStatus.from(update.state);
      if (status == _current) return;
      _current = status;
      _changes.add(status);
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }
}
