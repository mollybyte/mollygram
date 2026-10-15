import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'message_store.dart';

/// A message someone deleted for everyone, as it was when it was last
/// seen.
final class DeletedMessage {
  const DeletedMessage({required this.message, required this.deletedAt});

  /// The whole message as TDLib sent it.
  final td.Message message;

  /// When it was deleted.
  final DateTime deletedAt;

  int get chatId => message.chatId;
  int get messageId => message.id;

  /// The user who sent it, or the chat for messages sent on behalf of a
  /// chat (as a negative TDLib chat id).
  int get senderId => senderIdOf(message.senderId);

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(message.date * 1000);

  static int senderIdOf(td.MessageSender sender) => switch (sender) {
    td.MessageSenderUser(:final userId) => userId,
    td.MessageSenderChat(:final chatId) => chatId,
  };
}

/// Deleted messages kept per chat.
final class DeletedMessagesStore {
  DeletedMessagesStore(this._db);

  static const table = 'deleted_messages';

  final StoreDatabase _db;

  /// Keeps [message], deleted at [deletedAt].
  Future<void> save(td.Message message, {required DateTime deletedAt}) async {
    await _db.customInsert(
      'INSERT OR REPLACE INTO $table '
      '(chat_id, message_id, sender_id, date, deleted_at, message) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withInt(message.chatId),
        Variable.withInt(message.id),
        Variable.withInt(DeletedMessage.senderIdOf(message.senderId)),
        Variable.withInt(message.date),
        Variable.withInt(deletedAt.millisecondsSinceEpoch ~/ 1000),
        Variable.withString(jsonEncode(message.toJson())),
      ],
    );
    _db.notifyUpdates({const TableUpdate(table)});
  }

  /// The deleted messages of [chatId], oldest first.
  Future<List<DeletedMessage>> forChat(int chatId) async {
    final rows = await _db
        .customSelect(
          'SELECT message, deleted_at FROM $table '
          'WHERE chat_id = ? ORDER BY message_id',
          variables: [Variable.withInt(chatId)],
        )
        .get();
    return [for (final row in rows) ?_read(row)];
  }

  /// [forChat], again whenever a message is kept or the store cleared.
  Stream<List<DeletedMessage>> watchChat(int chatId) =>
      _db.watch(table, () => forChat(chatId));

  /// One deleted message, or null.
  Future<DeletedMessage?> find(int chatId, int messageId) async {
    final row = await _db
        .customSelect(
          'SELECT message, deleted_at FROM $table '
          'WHERE chat_id = ? AND message_id = ?',
          variables: [Variable.withInt(chatId), Variable.withInt(messageId)],
        )
        .getSingleOrNull();
    return row == null ? null : _read(row);
  }

  /// A row that no longer decodes (a TDLib update changed the format) is
  /// skipped rather than failing the whole list.
  DeletedMessage? _read(QueryRow row) {
    try {
      final message = td.tdFromJson(
        jsonDecode(row.read<String>('message')) as Map<String, Object?>,
      );
      if (message is! td.Message) return null;
      return DeletedMessage(
        message: message,
        deletedAt: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('deleted_at') * 1000,
        ),
      );
    } on Object {
      return null;
    }
  }
}
