import 'dart:async';
import 'dart:typed_data';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// Where a secret chat is in its life.
enum SecretChatStatus {
  /// Created, waiting for the other person's app to come online and
  /// accept the key exchange.
  pending,

  /// Keys exchanged: messages go end to end.
  ready,

  /// Closed by either side; nothing more can be sent.
  closed,
}

/// A secret chat as the app shows it.
final class SecretChatInfo {
  const SecretChatInfo({
    required this.id,
    required this.userId,
    required this.status,
    required this.isOutbound,
    required this.keyHash,
    this.layer = 0,
  });

  factory SecretChatInfo.from(td.SecretChat chat) => SecretChatInfo(
    id: chat.id,
    userId: chat.userId,
    status: switch (chat.state) {
      td.SecretChatStatePending() => SecretChatStatus.pending,
      td.SecretChatStateReady() => SecretChatStatus.ready,
      td.SecretChatStateClosed() => SecretChatStatus.closed,
    },
    isOutbound: chat.isOutbound,
    keyHash: chat.keyHash,
    layer: chat.layer,
  );

  /// TDLib's secret chat id; the chat itself is [chatId].
  final int id;

  /// The other person.
  final int userId;
  final SecretChatStatus status;

  /// Started by this user.
  final bool isOutbound;

  /// The hash of the key both sides use, for [SecretKeyImage]; empty
  /// until the chat is ready.
  final Uint8List keyHash;
  final int layer;

  /// The id of the chat that holds this secret chat's messages.
  int get chatId => SecretChatsController.chatIdOf(id);
}

/// The picture and text that let two people check they share the same
/// key, drawn the way the official apps draw them so they can be compared
/// across apps: the key hash read two bits at a time (lowest bits of each
/// byte first) as a 12×12 grid in four colours, and the first 32 bytes as
/// hex.
abstract final class SecretKeyImage {
  /// Pixels per side.
  static const size = 12;

  /// The four colours as ARGB, in the order of the two-bit values.
  static const colors = [0xFFFFFFFF, 0xFFD5E6F3, 0xFF2D5775, 0xFF2F99C9];

  /// [size]² colour indexes (0..3), row by row, from the top left. Empty
  /// when the hash is too short for a whole picture.
  static List<int> pixels(Uint8List keyHash) {
    const count = size * size;
    if (keyHash.length * 4 < count) return const [];
    return [
      for (var bit = 0; bit < count * 2; bit += 2)
        (keyHash[bit ~/ 8] >> (bit % 8)) & 0x3,
    ];
  }

  /// The first 32 bytes as two-digit upper-case hex, in order.
  static List<String> hex(Uint8List keyHash) => [
    for (final byte in keyHash.take(32))
      byte.toRadixString(16).padLeft(2, '0').toUpperCase(),
  ];
}

/// Secret chats: starting and closing them, following their state, and
/// their self-destruct timer.
final class SecretChatsController {
  SecretChatsController(this._client);

  final td.TdClient _client;
  final _chats = <int, SecretChatInfo>{};
  final _timers = <int, int>{};
  final _changes = StreamController<int>.broadcast(sync: true);
  StreamSubscription<td.TdObject>? _subscription;

  /// TDLib's chat ids for secret chats sit around this one: the chat of
  /// secret chat `n` is `base + n`.
  static const _base = -2000000000000;

  /// The self-destruct times offered, in seconds; 0 is off. The same
  /// steps as the official apps.
  static const selfDestructTimes = [
    0,
    1,
    2,
    3,
    4,
    5,
    10,
    15,
    30,
    60,
    3600,
    86400,
    604800,
  ];

  /// The chat id of secret chat [secretChatId].
  static int chatIdOf(int secretChatId) => _base + secretChatId;

  /// The secret chat id of [chatId], or null when it is not a secret chat.
  static int? secretChatIdOf(int chatId) {
    // Secret chat ids are any non-zero 32-bit number (TDLib's DialogId).
    final id = chatId - _base;
    return id != 0 && id >= -0x80000000 && id <= 0x7fffffff ? id : null;
  }

  /// Fires with a chat id when its secret chat or timer changes.
  Stream<int> get changes => _changes.stream;

  Future<void> start() async {
    _subscription ??= _client.updates.listen(_onUpdate);
  }

  void _onUpdate(td.TdObject update) {
    switch (update) {
      case td.UpdateSecretChat(:final secretChat):
        final info = SecretChatInfo.from(secretChat);
        _chats[info.id] = info;
        _changes.add(info.chatId);
      case td.UpdateNewChat(:final chat) when chat.type is td.ChatTypeSecret:
        _timers[chat.id] = chat.messageAutoDeleteTime;
        _changes.add(chat.id);
      case td.UpdateChatMessageAutoDeleteTime(
            :final chatId,
            :final messageAutoDeleteTime,
          )
          when secretChatIdOf(chatId) != null:
        _timers[chatId] = messageAutoDeleteTime;
        _changes.add(chatId);
      default:
    }
  }

  /// The secret chat in [chatId], as last seen; null when it is not one or
  /// TDLib hasn't sent it yet (see [load]).
  SecretChatInfo? forChat(int chatId) {
    final id = secretChatIdOf(chatId);
    return id == null ? null : _chats[id];
  }

  /// The secret chat in [chatId], asked of TDLib when it isn't known.
  Future<SecretChatInfo?> load(int chatId) async {
    final known = forChat(chatId);
    if (known != null) return known;
    final id = secretChatIdOf(chatId);
    if (id == null) return null;
    final info = SecretChatInfo.from(
      await _client.send(td.GetSecretChat(secretChatId: id)),
    );
    // An update that arrived while asking is newer than the answer.
    return _chats.putIfAbsent(id, () => info);
  }

  /// Starts a secret chat with [userId]; completes with its chat id. The
  /// chat stays [SecretChatStatus.pending] until their app accepts it.
  Future<int> create(int userId) async {
    final chat = await _client.send(td.CreateNewSecretChat(userId: userId));
    if (chat.type case td.ChatTypeSecret(:final secretChatId)) {
      final secret = await _client.send(
        td.GetSecretChat(secretChatId: secretChatId),
      );
      _chats.putIfAbsent(secretChatId, () => SecretChatInfo.from(secret));
    }
    _timers.putIfAbsent(chat.id, () => chat.messageAutoDeleteTime);
    return chat.id;
  }

  /// Closes the secret chat in [chatId] for both sides. The chat and its
  /// messages stay until deleted with [delete].
  Future<void> close(int chatId) async {
    final id = secretChatIdOf(chatId);
    if (id == null) return;
    await _client.send(td.CloseSecretChat(secretChatId: id));
  }

  /// Deletes the secret chat in [chatId] from the chat list, with its
  /// messages; an open one is closed first.
  Future<void> delete(int chatId) async {
    if (forChat(chatId)?.status != SecretChatStatus.closed) {
      await close(chatId);
    }
    await _client.send(
      td.DeleteChatHistory(
        chatId: chatId,
        removeFromChatList: true,
        revoke: true,
      ),
    );
  }

  /// The self-destruct time of new messages in [chatId], in seconds; 0
  /// when off.
  int selfDestructTime(int chatId) => _timers[chatId] ?? 0;

  /// Sets the self-destruct time of messages sent from now on.
  Future<void> setSelfDestructTime(int chatId, int seconds) async {
    await _client.send(
      td.SetChatMessageAutoDeleteTime(
        chatId: chatId,
        messageAutoDeleteTime: seconds,
      ),
    );
    _timers[chatId] = seconds;
    _changes.add(chatId);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }
}
