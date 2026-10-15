import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/session/telegram_session_launcher.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

void main() {
  test('a session terminated elsewhere is replaced by a new one', () async {
    final clients = <_FakeTdJson>[];
    final container = ProviderContainer(
      overrides: [
        telegramApiConfigProvider.overrideWithValue(
          const TelegramApiConfig(
            apiId: 12345,
            apiHash: '0123456789abcdef0123456789abcdef',
          ),
        ),
        telegramSessionLauncherProvider.overrideWithValue(
          TelegramSessionLauncher(
            startTdlib: (_) async {
              final json = _FakeTdJson();
              clients.add(json);
              return td.Td.custom(json, td.InlineTdEventSource(json));
            },
            loadParameters: (api) async => TdlibParameters(
              api: api,
              databaseDirectory: '/tmp/mollygram/database',
              filesDirectory: '/tmp/mollygram/files',
              databaseEncryptionKey: Uint8List.fromList([1, 2, 3]),
              systemLanguageCode: 'en',
              deviceModel: 'Mac',
              applicationVersion: '0.1.0',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(telegramSessionProvider, (_, _) {});
    addTearDown(subscription.close);

    final first = await container.read(telegramSessionProvider.future);
    for (final state in [
      'authorizationStateReady',
      'authorizationStateLoggingOut',
      'authorizationStateClosing',
      'authorizationStateClosed',
    ]) {
      clients.single.push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': state},
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final second = await container.read(telegramSessionProvider.future);
    expect(second, isNot(same(first)));
    expect(clients, hasLength(2));
  });
}

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

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
    sent.add(decoded);
    final response = decoded['@type'] == 'getAuthorizationState'
        ? {'@type': 'authorizationStateWaitPhoneNumber'}
        : {'@type': 'ok'};
    _queue.add(
      jsonEncode({
        ...response,
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}
