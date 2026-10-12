import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;

  setUp(() {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
  });

  test(
    'initializes TDLib, then loads chats when authorization is ready',
    () async {
      final session = await TelegramSession.attach(
        tdlib,
        parameters: TdlibParameters(
          api: const TelegramApiConfig(
            apiId: 12345,
            apiHash: '0123456789abcdef0123456789abcdef',
          ),
          databaseDirectory: '/tmp/mollygram/database',
          filesDirectory: '/tmp/mollygram/files',
          databaseEncryptionKey: Uint8List.fromList([1, 2, 3]),
          systemLanguageCode: 'en',
          deviceModel: 'Mac',
          applicationVersion: '0.1.0',
        ),
      );
      await pumpEventQueue();

      expect(json.sent.map((request) => request['@type']), [
        'getAuthorizationState',
        'setTdlibParameters',
      ]);

      json.push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateReady'},
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await pumpEventQueue();

      expect(json.sent.last['@type'], 'loadChats');
      await session.dispose();
    },
  );
}

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var _nextClientId = 0;

  @override
  int createClientId() => ++_nextClientId;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    sent.add(decoded);
    if (decoded['@type'] == 'getAuthorizationState') {
      _queue.add(
        jsonEncode({
          '@type': 'authorizationStateWaitTdlibParameters',
          '@client_id': clientId,
          '@extra': decoded['@extra'],
        }),
      );
      return;
    }
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
