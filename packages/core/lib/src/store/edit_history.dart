import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'message_store.dart';

/// One earlier version of an edited message.
final class MessageVersion {
  const MessageVersion({
    required this.chatId,
    required this.messageId,
    required this.content,
    required this.date,
    required this.replacedAt,
  });

  final int chatId;
  final int messageId;
  final td.MessageContent content;

  /// When this version was written: the message's date, or the edit that
  /// made it.
  final DateTime date;

  /// When the next edit replaced it.
  final DateTime replacedAt;
}

/// Earlier versions of edited messages.
final class EditHistoryStore {
  EditHistoryStore(this._db);

  static const table = 'message_versions';

  final StoreDatabase _db;

  /// Keeps [content] as a version of the message, written at [date] and
  /// replaced at [replacedAt]. The same edit seen twice is kept once.
  Future<void> save({
    required int chatId,
    required int messageId,
    required td.MessageContent content,
    required DateTime date,
    required DateTime replacedAt,
  }) async {
    await _db.customInsert(
      'INSERT OR IGNORE INTO $table '
      '(chat_id, message_id, date, replaced_at, content) '
      'VALUES (?, ?, ?, ?, ?)',
      variables: [
        Variable.withInt(chatId),
        Variable.withInt(messageId),
        Variable.withInt(date.millisecondsSinceEpoch ~/ 1000),
        Variable.withInt(replacedAt.millisecondsSinceEpoch ~/ 1000),
        Variable.withString(jsonEncode(content.toJson())),
      ],
    );
    _db.notifyUpdates({const TableUpdate(table)});
  }

  /// The earlier versions of a message, oldest first; empty when it was
  /// never edited while the history was kept.
  Future<List<MessageVersion>> versions(int chatId, int messageId) async {
    final rows = await _db
        .customSelect(
          'SELECT date, replaced_at, content FROM $table '
          'WHERE chat_id = ? AND message_id = ? ORDER BY replaced_at, id',
          variables: [Variable.withInt(chatId), Variable.withInt(messageId)],
        )
        .get();
    return [for (final row in rows) ?_read(chatId, messageId, row)];
  }

  /// [versions], again whenever a version is kept or the store cleared.
  Stream<List<MessageVersion>> watchVersions(int chatId, int messageId) =>
      _db.watch(table, () => versions(chatId, messageId));

  MessageVersion? _read(int chatId, int messageId, QueryRow row) {
    try {
      final content = td.tdFromJson(
        jsonDecode(row.read<String>('content')) as Map<String, Object?>,
      );
      if (content is! td.MessageContent) return null;
      DateTime at(String column) =>
          DateTime.fromMillisecondsSinceEpoch(row.read<int>(column) * 1000);
      return MessageVersion(
        chatId: chatId,
        messageId: messageId,
        content: content,
        date: at('date'),
        replacedAt: at('replaced_at'),
      );
    } on Object {
      return null;
    }
  }
}
