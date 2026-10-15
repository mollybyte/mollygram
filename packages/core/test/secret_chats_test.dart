import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late SecretChatsController secrets;
  final chatId = SecretChatsController.chatIdOf(5);

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    secrets = SecretChatsController(tdlib.createClient());
    await secrets.start();
  });

  tearDown(() async {
    await secrets.dispose();
    await tdlib.close();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  test('chat ids map to secret chat ids and back', () {
    expect(SecretChatsController.chatIdOf(5), -1999999999995);
    expect(SecretChatsController.secretChatIdOf(-1999999999995), 5);
    expect(
      SecretChatsController.secretChatIdOf(
        SecretChatsController.chatIdOf(-2147483648),
      ),
      -2147483648,
    );
    expect(SecretChatsController.secretChatIdOf(42), isNull);
    expect(SecretChatsController.secretChatIdOf(-1001234567890), isNull);
    expect(SecretChatsController.secretChatIdOf(-100), isNull);
  });

  test('follows the state of a secret chat', () async {
    final seen = <int>[];
    secrets.changes.listen(seen.add);
    json.push(_update(5, 'secretChatStatePending'));
    await settle();
    expect(secrets.forChat(chatId)!.status, SecretChatStatus.pending);
    expect(secrets.forChat(chatId)!.userId, 7);

    json.push(_update(5, 'secretChatStateReady', keyHash: _hash()));
    await settle();
    final ready = secrets.forChat(chatId)!;
    expect(ready.status, SecretChatStatus.ready);
    expect(ready.keyHash, hasLength(36));
    expect(ready.chatId, chatId);

    json.push(_update(5, 'secretChatStateClosed'));
    await settle();
    expect(secrets.forChat(chatId)!.status, SecretChatStatus.closed);
    expect(seen, [chatId, chatId, chatId]);
    expect(secrets.forChat(42), isNull);
  });

  test('asks TDLib for a secret chat it has not seen', () async {
    json.answers['getSecretChat'] = _secretChat(5, 'secretChatStateReady');

    final info = await secrets.load(chatId);

    expect(info!.status, SecretChatStatus.ready);
    expect(json.sent.single['secret_chat_id'], 5);
    expect(await secrets.load(42), isNull);
  });

  test('an update that arrives while asking is not overwritten', () async {
    json
      ..answers['getSecretChat'] = _secretChat(5, 'secretChatStatePending')
      ..before['getSecretChat'] = [_update(5, 'secretChatStateReady')];

    final info = await secrets.load(chatId);

    expect(info!.status, SecretChatStatus.ready);
    expect(secrets.forChat(chatId)!.status, SecretChatStatus.ready);
  });

  test('creates a secret chat with a user', () async {
    json
      ..answers['createNewSecretChat'] = _chat(chatId, 5, autoDelete: 0)
      ..answers['getSecretChat'] = _secretChat(5, 'secretChatStatePending');

    final created = await secrets.create(7);

    expect(created, chatId);
    expect(json.sent.first, containsPair('user_id', 7));
    expect(secrets.forChat(chatId)!.status, SecretChatStatus.pending);
  });

  test('closes and deletes a secret chat', () async {
    json.push(_update(5, 'secretChatStateReady'));
    await settle();

    await secrets.delete(chatId);

    expect(json.sent.map((r) => r['@type']), [
      'closeSecretChat',
      'deleteChatHistory',
    ]);
    expect(json.sent.last['remove_from_chat_list'], isTrue);
    await secrets.close(42);
    expect(json.sent, hasLength(2));
  });

  test('a closed chat is deleted without closing it again', () async {
    json.push(_update(5, 'secretChatStateClosed'));
    await settle();

    await secrets.delete(chatId);

    expect(json.sent.map((r) => r['@type']), ['deleteChatHistory']);
  });

  test('follows and sets the self-destruct timer', () async {
    json.push({'@type': 'updateNewChat', 'chat': _chat(chatId, 5)});
    await settle();
    expect(secrets.selfDestructTime(chatId), 10);

    json.push({
      '@type': 'updateChatMessageAutoDeleteTime',
      'chat_id': chatId,
      'message_auto_delete_time': 60,
    });
    await settle();
    expect(secrets.selfDestructTime(chatId), 60);

    await secrets.setSelfDestructTime(chatId, 0);
    expect(json.sent.single, containsPair('message_auto_delete_time', 0));
    expect(secrets.selfDestructTime(chatId), 0);
    expect(SecretChatsController.selfDestructTimes.first, 0);
  });

  group('key image', () {
    test('reads two bits at a time, lowest first, into 12×12', () {
      final hash = Uint8List(36)
        ..[0] = 0x1B; // 00 01 10 11 → read from the low end: 3, 2, 1, 0
      final pixels = SecretKeyImage.pixels(hash);

      expect(pixels, hasLength(144));
      expect(pixels.take(5), [3, 2, 1, 0, 0]);
      expect(pixels.skip(4).every((p) => p == 0), isTrue);
    });

    test('the last byte fills the bottom right', () {
      final hash = Uint8List(36)..[35] = 0xC0;
      final pixels = SecretKeyImage.pixels(hash);

      expect(pixels.last, 3);
      expect(pixels[142], 0);
    });

    test('nothing for a hash too short to draw', () {
      expect(SecretKeyImage.pixels(Uint8List(10)), isEmpty);
    });

    test('hex shows the first 32 bytes', () {
      final hex = SecretKeyImage.hex(_hash());

      expect(hex, hasLength(32));
      expect(hex.first, '00');
      expect(hex[10], '0A');
      expect(hex.last, '1F');
    });

    test('four colours as in the official apps', () {
      expect(SecretKeyImage.colors, [
        0xFFFFFFFF,
        0xFFD5E6F3,
        0xFF2D5775,
        0xFF2F99C9,
      ]);
    });
  });
}

Uint8List _hash() => Uint8List.fromList(List.generate(36, (i) => i));

Map<String, Object?> _secretChat(int id, String state, {Uint8List? keyHash}) =>
    {
      '@type': 'secretChat',
      'id': id,
      'user_id': 7,
      'state': {'@type': state},
      'is_outbound': true,
      'key_hash': base64.encode(keyHash ?? Uint8List(0)),
      'layer': 144,
    };

Map<String, Object?> _update(int id, String state, {Uint8List? keyHash}) => {
  '@type': 'updateSecretChat',
  'secret_chat': _secretChat(id, state, keyHash: keyHash),
};

Map<String, Object?> _chat(int id, int secretChatId, {int autoDelete = 10}) => {
  '@type': 'chat',
  'id': id,
  'type': {
    '@type': 'chatTypeSecret',
    'secret_chat_id': secretChatId,
    'user_id': 7,
  },
  'title': 'Anna',
  'permissions': {'@type': 'chatPermissions'},
  'positions': <Object?>[],
  'chat_lists': <Object?>[],
  'notification_settings': {'@type': 'chatNotificationSettings'},
  'available_reactions': {
    '@type': 'chatAvailableReactionsAll',
    'max_reaction_count': 11,
  },
  'video_chat': {'@type': 'videoChat'},
  'message_auto_delete_time': autoDelete,
};

/// A TDLib that answers from [answers] by request type (`ok` otherwise)
/// and delivers what [push] queues.
final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  final answers = <String, Map<String, Object?>>{};

  /// Updates delivered just before the answer to a request type.
  final before = <String, List<Map<String, Object?>>>{};

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
    final type = decoded['@type']! as String;
    if (type != 'close') sent.add(decoded);
    before.remove(type)?.forEach(push);
    _queue.add(
      jsonEncode({
        ...answers[type] ?? {'@type': 'ok'},
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (type == 'close') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
    }
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}
