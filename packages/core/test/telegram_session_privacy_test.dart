import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late TelegramSession session;

  setUp(() async {
    json = _FakeTdJson();
    session = await TelegramSession.attach(
      td.Td.custom(json, td.InlineTdEventSource(json)),
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
      privacy: const PrivacySettings.ghost(),
    );
  });

  tearDown(() => session.dispose());

  Iterable<Object?> sentTypes() => json.sent.map((r) => r['@type']);

  test('reading a chat sends no read receipts in ghost mode', () async {
    await session.conversations.viewMessages(7, [1, 2]);
    expect(sentTypes(), isNot(contains('viewMessages')));
    expect(session.privacy.readUpTo(7), 2);
  });

  test('"Mark as read" on a notification is sent all the same', () async {
    await session.notifications.markRead(7, 2);
    final view = json.sent.singleWhere((r) => r['@type'] == 'viewMessages');
    expect(view['force_read'], isTrue);
  });

  test('nothing slips through while the session closes', () async {
    // A chat view closing late, just as TDLib is asked to close.
    json.onClose = () => unawaited(
      session.conversations.viewMessages(7, [3]).catchError((Object _) {}),
    );
    await session.dispose();
    expect(sentTypes(), isNot(contains('viewMessages')));
  });
}

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

  /// Runs when the client is asked to close.
  void Function()? onClose;

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
    final type = decoded['@type'];
    if (type == 'close') onClose?.call();
    if (type != 'close') sent.add(decoded);
    final response = type == 'getAuthorizationState'
        ? {'@type': 'authorizationStateWaitPhoneNumber'}
        : {'@type': 'ok'};
    _queue.add(
      jsonEncode({
        ...response,
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (type == 'close') {
      _queue.add(
        jsonEncode({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateClosed'},
          '@client_id': clientId,
        }),
      );
    }
  }
}
