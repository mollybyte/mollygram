import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late ConnectionMonitor monitor;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    monitor = ConnectionMonitor(tdlib.createClient());
    await monitor.start();
  });

  tearDown(() async {
    await monitor.dispose();
    await tdlib.close();
  });

  void push(String state) => json.push({
    '@type': 'updateConnectionState',
    'state': {'@type': state},
  });

  test('starts ready and follows updateConnectionState', () async {
    expect(monitor.current, ConnectionStatus.ready);
    final seen = <ConnectionStatus>[];
    monitor.changes.listen(seen.add);

    push('connectionStateWaitingForNetwork');
    push('connectionStateConnectingToProxy');
    push('connectionStateConnecting');
    push('connectionStateConnecting');
    push('connectionStateUpdating');
    push('connectionStateReady');
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(seen, [
      ConnectionStatus.waitingForNetwork,
      ConnectionStatus.connectingToProxy,
      ConnectionStatus.connecting,
      ConnectionStatus.updating,
      ConnectionStatus.ready,
    ]);
    expect(monitor.current, ConnectionStatus.ready);
  });
}

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();

  @override
  int createClientId() => 1;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    _queue.add(
      jsonEncode({
        '@type': 'ok',
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (decoded['@type'] == 'close') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
    }
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}
