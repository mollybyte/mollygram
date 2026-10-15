import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:mollygram_core/mollygram_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  final key = List<int>.generate(32, (i) => i);
  late MessageStore store;

  // Each test opens its own store.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() async => store = await MessageStore.memory(key: key));
  tearDown(() => store.close());

  group('deleted messages', () {
    test('keeps a message per chat and reads it back whole', () async {
      final deletedAt = DateTime.fromMillisecondsSinceEpoch(1700000100000);
      await store.deleted.save(message(7, 2, 'second'), deletedAt: deletedAt);
      await store.deleted.save(message(7, 1, 'first'), deletedAt: deletedAt);
      await store.deleted.save(message(8, 1, 'other'), deletedAt: deletedAt);

      final kept = await store.deleted.forChat(7);
      expect(
        [for (final m in kept) textOf(m.message.content)],
        ['first', 'second'],
      );
      expect(kept.first.senderId, 42);
      expect(kept.first.deletedAt, deletedAt);
      expect(kept.first.date.millisecondsSinceEpoch, 1700000000000);
      expect((await store.deleted.find(8, 1))!.chatId, 8);
      expect(await store.deleted.find(8, 2), isNull);
    });

    test('a chat stream follows what is kept and cleared', () async {
      final seen = <int>[];
      final subscription = store.deleted
          .watchChat(7)
          .listen((list) => seen.add(list.length));
      await pumpEventQueue();

      await store.deleted.save(message(7, 1, 'a'), deletedAt: DateTime(2026));
      await pumpEventQueue();
      await store.clear();
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [0, 1, 0]);
    });
  });

  group('edit history', () {
    test('versions come oldest first and an edit is kept once', () async {
      Future<void> save(String text, int replacedAt) => store.edits.save(
        chatId: 7,
        messageId: 1,
        content: message(7, 1, text).content,
        date: DateTime.fromMillisecondsSinceEpoch((replacedAt - 60) * 1000),
        replacedAt: DateTime.fromMillisecondsSinceEpoch(replacedAt * 1000),
      );
      await save('second', 1700000200);
      await save('first', 1700000100);
      await save('first', 1700000100);

      final versions = await store.edits.versions(7, 1);
      expect(
        [for (final v in versions) textOf(v.content)],
        ['first', 'second'],
      );
      expect(versions.first.replacedAt.millisecondsSinceEpoch, 1700000100000);
      expect(await store.edits.versions(7, 2), isEmpty);
    });
  });

  test('reports its size and clears everything', () async {
    await store.deleted.save(message(7, 1, 'a'), deletedAt: DateTime(2026));
    await store.edits.save(
      chatId: 7,
      messageId: 2,
      content: message(7, 2, 'b').content,
      date: DateTime(2026),
      replacedAt: DateTime(2026, 2),
    );
    expect(await store.sizeInBytes(), greaterThan(0));

    await store.clear();
    expect(await store.deleted.forChat(7), isEmpty);
    expect(await store.edits.versions(7, 2), isEmpty);
  });

  group('on disk', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('store'));
    tearDown(() => dir.delete(recursive: true));

    test('is encrypted and opens only with its key', () async {
      final path = '${dir.path}/accounts/0/mollygram.db';
      final first = await MessageStore.open(path: path, key: key);
      await first.deleted.save(
        message(7, 1, 'a secret'),
        deletedAt: DateTime(2026),
      );
      await first.close();

      final bytes = await File(path).readAsBytes();
      expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'));
      expect(String.fromCharCodes(bytes), isNot(contains('a secret')));

      final again = await MessageStore.open(path: path, key: key);
      expect(await again.deleted.forChat(7), hasLength(1));
      await again.close();

      await expectLater(
        MessageStore.open(path: path, key: List.filled(32, 9)),
        throwsA(isA<StoreKeyLost>()),
      );
    });

    test('version 1 files keep opening', () async {
      final path = '${dir.path}/mollygram.db';
      await (await MessageStore.open(path: path, key: key)).close();
      final again = await MessageStore.open(path: path, key: key);
      expect(await again.schemaVersion(), 1);
      await again.close();
    });

    test('measures and deletes its files without opening them', () async {
      final path = '${dir.path}/mollygram.db';
      expect(await MessageStore.sizeOnDisk(path), 0);
      final opened = await MessageStore.open(path: path, key: key);
      await opened.deleted.saveAll([
        message(7, 1, 'a'),
        message(7, 2, 'b'),
      ], deletedAt: DateTime(2026));
      expect(await opened.count(), 2);
      await opened.close();

      expect(await MessageStore.sizeOnDisk(path), await File(path).length());
      await MessageStore.deleteAt(path);
      expect(await MessageStore.sizeOnDisk(path), 0);
      expect(File(path).existsSync(), isFalse);
    });

    test('is not opened without SQLCipher', () async {
      // Plain SQLite has no answer to the check.
      MessageStore.cipherCheck = 'SELECT 1 WHERE 0';
      addTearDown(() => MessageStore.cipherCheck = 'PRAGMA cipher_version');
      final path = '${dir.path}/mollygram.db';

      await expectLater(
        MessageStore.open(path: path, key: key),
        throwsA(isA<StoreNotEncrypted>()),
      );
      await expectLater(
        MessageStore.memory(key: key),
        throwsA(isA<StoreNotEncrypted>()),
      );
    });
  });

  test('a store path and key per account slot', () async {
    expect(
      messageStorePathFor('/support', 3),
      '/support${Platform.pathSeparator}accounts${Platform.pathSeparator}3'
      '${Platform.pathSeparator}mollygram.db',
    );
    final secrets = _MemorySecrets();
    final first = await messageStoreKeyFor(3, secrets);
    expect(first, hasLength(32));
    expect(await messageStoreKeyFor(3, secrets), first);
    expect(secrets.values.keys, ['mollygram.store.database-key.v1.account-3']);
  });

  test('no new key for a store that exists: its key is lost', () async {
    final secrets = _MemorySecrets();
    await expectLater(
      messageStoreKeyFor(3, secrets, storeExists: true),
      throwsA(isA<StoreKeyLost>()),
    );
    expect(secrets.values, isEmpty);

    secrets.values[messageStoreKeyNameFor(3)] = 'not base64!';
    await expectLater(
      messageStoreKeyFor(3, secrets, storeExists: true),
      throwsA(isA<StoreKeyLost>()),
    );

    await deleteMessageStoreKey(3, secrets);
    expect(await messageStoreKeyFor(3, secrets), hasLength(32));
  });
}

final class _MemorySecrets implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
