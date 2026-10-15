import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'deleted_messages.dart';
import 'edit_history.dart';

/// Thrown when the SQLite library in use cannot encrypt, so the store is
/// not opened rather than written in the clear.
final class StoreNotEncrypted implements Exception {
  const StoreNotEncrypted();

  @override
  String toString() => 'StoreNotEncrypted: SQLCipher is not available';
}

/// Mollygram's own database for one account, next to TDLib's: the
/// messages TDLib forgets, kept only while the user asks for it (deleted
/// messages, edit history). Encrypted with SQLCipher; the schema is in
/// docs/privacy-store.md.
final class MessageStore {
  MessageStore._(this._db)
    : deleted = DeletedMessagesStore(_db),
      edits = EditHistoryStore(_db);

  /// Opens or creates the store at [path], encrypted with [key].
  static Future<MessageStore> open({
    required String path,
    required List<int> key,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final store = MessageStore._(
      StoreDatabase(NativeDatabase(file, setup: (db) => _unlock(db, key))),
    );
    await store._db.ready();
    return store;
  }

  /// A store in memory, for tests.
  static Future<MessageStore> memory({List<int>? key}) async {
    final store = MessageStore._(
      StoreDatabase(
        NativeDatabase.memory(
          setup: key == null ? null : (db) => _unlock(db, key),
        ),
      ),
    );
    await store._db.ready();
    return store;
  }

  static void _unlock(sqlite.Database db, List<int> key) {
    final version = db.select('PRAGMA cipher_version');
    if (version.isEmpty) throw const StoreNotEncrypted();
    final hex = [for (final byte in key) byte.toRadixString(16).padLeft(2, '0')]
        .join();
    db.execute("PRAGMA key = \"x'$hex'\"");
    // Fails with "file is not a database" when the key is wrong.
    db.select('SELECT count(*) FROM sqlite_master');
  }

  final StoreDatabase _db;
  final DeletedMessagesStore deleted;
  final EditHistoryStore edits;

  /// How much space the store takes, in bytes.
  Future<int> sizeInBytes() async {
    final row = await _db
        .customSelect(
          'SELECT page_count * page_size AS size '
          'FROM pragma_page_count(), pragma_page_size()',
        )
        .getSingle();
    return row.read<int>('size');
  }

  /// Forgets every stored message and gives the space back.
  Future<void> clear() async {
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM deleted_messages');
      await _db.customStatement('DELETE FROM message_versions');
    });
    await _db.customStatement('VACUUM');
    _db.notifyUpdates({
      const TableUpdate(DeletedMessagesStore.table),
      const TableUpdate(EditHistoryStore.table),
    });
  }

  Future<void> close() => _db.close();
}

/// The drift database, with its schema in SQL rather than generated
/// table classes: two tables, read and written by hand.
final class StoreDatabase extends GeneratedDatabase {
  StoreDatabase(super.executor);

  static const _schema = [
    '''
    CREATE TABLE deleted_messages (
      chat_id INTEGER NOT NULL,
      message_id INTEGER NOT NULL,
      sender_id INTEGER NOT NULL,
      date INTEGER NOT NULL,
      deleted_at INTEGER NOT NULL,
      message TEXT NOT NULL,
      PRIMARY KEY (chat_id, message_id)
    ) WITHOUT ROWID
    ''',
    '''
    CREATE TABLE message_versions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      chat_id INTEGER NOT NULL,
      message_id INTEGER NOT NULL,
      date INTEGER NOT NULL,
      replaced_at INTEGER NOT NULL,
      content TEXT NOT NULL,
      UNIQUE (chat_id, message_id, replaced_at)
    )
    ''',
  ];

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final statement in _schema) {
        await customStatement(statement);
      }
    },
  );

  /// Opens the database, creating the tables the first time.
  Future<void> ready() => customSelect('SELECT 1').get();

  /// Re-runs [query] whenever [table] changes.
  Stream<T> watch<T>(String table, Future<T> Function() query) =>
      Stream<T>.multi((controller) {
        var running = Future<void>.value();
        var cancelled = false;
        void run() {
          running = running.then((_) async {
            try {
              final result = await query();
              if (!cancelled) controller.add(result);
            } on Object catch (error, stack) {
              if (!cancelled) controller.addError(error, stack);
            }
          });
        }

        final updates = tableUpdates(TableUpdateQuery.onTableName(table))
            .listen((_) => run());
        run();
        controller.onCancel = () {
          cancelled = true;
          // Not awaited: drift completes the cancel only on its next
          // update.
          unawaited(updates.cancel());
        };
      });
}
