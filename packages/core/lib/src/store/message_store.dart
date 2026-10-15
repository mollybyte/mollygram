import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
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

/// The store's key is gone or wrong (the keychain entry was lost or
/// reset), so its file can't be read. The only way on is to delete the
/// file and start again; there is no other copy of the key.
final class StoreKeyLost implements Exception {
  const StoreKeyLost();

  @override
  String toString() => 'StoreKeyLost: the store key does not open the store';
}

/// Mollygram's own database for one account, next to TDLib's: the
/// messages TDLib forgets, kept only while the user asks for it (deleted
/// messages, edit history). Encrypted with SQLCipher; the schema is in
/// docs/privacy-store.md.
final class MessageStore {
  MessageStore._(this._db)
    : deleted = DeletedMessagesStore(_db),
      edits = EditHistoryStore(_db);

  /// Opens or creates the store at [path], encrypted with [key]. SQLite
  /// runs on a background isolate, so writes never hold up a frame.
  ///
  /// Throws [StoreKeyLost] when [key] does not open an existing file, and
  /// [StoreNotEncrypted] when SQLCipher is missing. There is no way to
  /// change the key of an existing store.
  static Future<MessageStore> open({
    required String path,
    required List<int> key,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final copy = List<int>.of(key);
    final check = cipherCheck;
    return _ready(
      MessageStore._(
        StoreDatabase(
          NativeDatabase.createInBackground(
            file,
            setup: (db) => _unlock(db, copy, check),
          ),
        ),
      ),
    );
  }

  /// A store in memory, for tests; [key] makes it require SQLCipher.
  static Future<MessageStore> memory({List<int>? key}) => _ready(
    MessageStore._(
      StoreDatabase(
        NativeDatabase.memory(
          setup: key == null ? null : (db) => _unlock(db, key, cipherCheck),
        ),
      ),
    ),
  );

  static Future<MessageStore> _ready(MessageStore store) async {
    try {
      await store._db.ready();
      return store;
    } catch (error) {
      await store._db.close().catchError((Object _) {});
      final cause = error is DriftRemoteException ? error.remoteCause : error;
      // SQLITE_NOTADB: the key does not decrypt the file.
      if (cause is sqlite.SqliteException && cause.resultCode == 26) {
        throw const StoreKeyLost();
      }
      if (cause is StoreNotEncrypted) throw cause;
      rethrow;
    }
  }

  /// The files of the store at [path]: the database and SQLite's journals.
  static List<File> filesAt(String path) => [
    for (final suffix in ['', '-journal', '-wal', '-shm']) File('$path$suffix'),
  ];

  /// What the store at [path] takes on disk, without opening it.
  static Future<int> sizeOnDisk(String path) async {
    var size = 0;
    for (final file in filesAt(path)) {
      if (await file.exists()) size += await file.length();
    }
    return size;
  }

  /// Deletes the store at [path]; it must be closed.
  static Future<void> deleteAt(String path) async {
    for (final file in filesAt(path)) {
      if (await file.exists()) await file.delete();
    }
  }

  /// The query that tells SQLCipher from plain SQLite: only SQLCipher
  /// answers it. Tests point it at one that answers like plain SQLite.
  static var cipherCheck = 'PRAGMA cipher_version';

  static void _unlock(sqlite.Database db, List<int> key, String check) {
    final version = db.select(check);
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

  /// How many messages and versions are kept.
  Future<int> count() async {
    final row = await _db
        .customSelect(
          'SELECT (SELECT count(*) FROM deleted_messages) + '
          '(SELECT count(*) FROM message_versions) AS n',
        )
        .getSingle();
    return row.read<int>('n');
  }

  /// The schema version the file was written with.
  Future<int> schemaVersion() async {
    final row = await _db.customSelect('PRAGMA user_version').getSingle();
    return row.read<int>('user_version');
  }

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
