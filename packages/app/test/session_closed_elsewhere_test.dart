import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/home/workspace_storage.dart';
import 'package:mollygram/src/privacy/privacy_settings.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/session/telegram_session_launcher.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

void main() {
  late List<_FakeTdJson> clients;
  late MemoryWorkspaceStorage storage;

  /// A container whose launcher creates a fake TDLib per session; the
  /// first one closes as it starts when [closeWhileStarting].
  ProviderContainer create({bool closeWhileStarting = false}) {
    clients = [];
    storage = MemoryWorkspaceStorage({'tabs': <Object?>[]});
    final container = ProviderContainer(
      overrides: [
        telegramApiConfigProvider.overrideWithValue(
          const TelegramApiConfig(
            apiId: 12345,
            apiHash: '0123456789abcdef0123456789abcdef',
          ),
        ),
        workspaceStorageProvider.overrideWithValue(storage),
        privacySettingsStorageProvider.overrideWithValue(
          MemoryPrivacySettingsStorage(),
        ),
        telegramSessionLauncherProvider.overrideWithValue(
          TelegramSessionLauncher(
            startTdlib: (_) async {
              final json = _FakeTdJson(
                closeWhileStarting: closeWhileStarting && clients.isEmpty,
              );
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
    return container;
  }

  test('a session terminated elsewhere is replaced by a new one', () async {
    final container = create();
    final first = await container.read(telegramSessionProvider.future);
    container
        .read(selectedChatListProvider.notifier)
        .select(const ChatListLocation.folder(3));
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
    // What belonged to the account is forgotten.
    expect(storage.saved, isNull);
    expect(container.read(selectedChatListProvider).isMain, isTrue);
  });

  test('a session closed while starting is replaced too', () async {
    final container = create(closeWhileStarting: true);
    await container.read(telegramSessionProvider.future);

    expect(clients, hasLength(2));
    expect(storage.saved, isNull);
  });
}

final class _FakeTdJson implements td.TdJson {
  _FakeTdJson({this.closeWhileStarting = false});

  /// Asks for parameters and closes when they arrive.
  final bool closeWhileStarting;
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
    if (closeWhileStarting && decoded['@type'] == 'setTdlibParameters') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
      return;
    }
    final response = decoded['@type'] == 'getAuthorizationState'
        ? {
            '@type': closeWhileStarting
                ? 'authorizationStateWaitTdlibParameters'
                : 'authorizationStateWaitPhoneNumber',
          }
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
