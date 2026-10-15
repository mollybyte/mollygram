import 'dart:async';
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
      expect(session.conversations, isA<ConversationController>());
      await session.dispose();
    },
  );

  group('closedElsewhere', () {
    Future<TelegramSession> attach() => TelegramSession.attach(
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

    void state(String type) => json.push({
      '@type': 'updateAuthorizationState',
      'authorization_state': {'@type': type},
    });

    test('completes when the session is terminated elsewhere', () async {
      final session = await attach();
      var closed = false;
      unawaited(session.closedElsewhere.then((_) => closed = true));
      state('authorizationStateReady');
      state('authorizationStateLoggingOut');
      state('authorizationStateClosing');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(closed, isFalse);

      state('authorizationStateClosed');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(closed, isTrue);
      await session.dispose();
    });

    test('stays pending when the app logs out itself', () async {
      final session = await attach();
      var closed = false;
      unawaited(session.closedElsewhere.then((_) => closed = true));
      json.push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {
          '@type': 'authorizationStateWaitOtherDeviceConfirmation',
          'link': 'tg://login?token=a',
        },
      });
      final leaving = session.authorization.abandonQrCode();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      state('authorizationStateLoggingOut');
      state('authorizationStateClosed');
      await leaving;
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(closed, isFalse);
      await session.dispose();
    });

    test('stays pending when the session is disposed', () async {
      final session = await attach();
      var closed = false;
      unawaited(session.closedElsewhere.then((_) => closed = true));
      await session.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(closed, isFalse);
    });
  });

  test('fails to start when TDLib rejects its parameters', () async {
    // Missing credentials are refused before anything is sent; a wrong
    // database key would fail the same way. Either must reach the caller
    // instead of leaving the app on the starting screen.
    await expectLater(
      TelegramSession.attach(
        tdlib,
        parameters: TdlibParameters(
          api: const TelegramApiConfig(apiId: 0, apiHash: ''),
          databaseDirectory: '/tmp/mollygram/database',
          filesDirectory: '/tmp/mollygram/files',
          databaseEncryptionKey: Uint8List.fromList([1, 2, 3]),
          systemLanguageCode: 'en',
          deviceModel: 'Mac',
          applicationVersion: '0.1.0',
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('reports a parameter error returned by TDLib', () async {
    json.failParameters = true;
    await expectLater(
      TelegramSession.attach(
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
      ),
      throwsA(
        isA<td.TdException>().having(
          (error) => error.message,
          'message',
          'Wrong database encryption key',
        ),
      ),
    );
  });
}

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var failParameters = false;
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
    if (failParameters && decoded['@type'] == 'setTdlibParameters') {
      _queue.add(
        jsonEncode({
          '@type': 'error',
          'code': 401,
          'message': 'Wrong database encryption key',
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
