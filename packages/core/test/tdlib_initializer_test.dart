import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late TdlibInitializer initializer;

  setUp(() {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    initializer = TdlibInitializer(
      tdlib.createClient(),
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
  });

  tearDown(() async {
    await tdlib.close();
  });

  test(
    'sends the TDLib parameters without exposing the encryption key',
    () async {
      await initializer.initialize();

      final request = json.sent.single;
      expect(request['@type'], 'setTdlibParameters');
      expect(request['api_id'], 12345);
      expect(request['api_hash'], '0123456789abcdef0123456789abcdef');
      expect(request['database_directory'], '/tmp/mollygram/database');
      expect(request['files_directory'], '/tmp/mollygram/files');
      expect(request['database_encryption_key'], 'AQID');
      expect(request['use_file_database'], isTrue);
      expect(request['use_chat_info_database'], isTrue);
      expect(request['use_message_database'], isTrue);
      expect(request['use_secret_chats'], isTrue);
    },
  );

  test('initializes at most once', () async {
    await initializer.initialize();
    await initializer.initialize();

    expect(json.sent, hasLength(1));
  });

  test('rejects absent Telegram credentials before contacting TDLib', () async {
    final unconfigured = TdlibInitializer(
      tdlib.createClient(),
      parameters: TdlibParameters(
        api: const TelegramApiConfig(apiId: 0, apiHash: ''),
        databaseDirectory: '/tmp/mollygram/database',
        filesDirectory: '/tmp/mollygram/files',
        databaseEncryptionKey: Uint8List.fromList([1]),
        systemLanguageCode: 'en',
        deviceModel: 'Mac',
        applicationVersion: '0.1.0',
      ),
    );

    await expectLater(unconfigured.initialize(), throwsStateError);
    expect(json.sent, isEmpty);
  });
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
    _queue.add(
      jsonEncode({
        '@type': 'ok',
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (decoded['@type'] == 'close') {
      _queue.add(
        jsonEncode({
          '@type': 'updateAuthorizationState',
          '@client_id': clientId,
          'authorization_state': {'@type': 'authorizationStateClosed'},
        }),
      );
    }
  }
}
