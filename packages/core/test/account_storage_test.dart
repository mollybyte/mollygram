import 'dart:convert';
import 'dart:io';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AccountStorage storage;
  final sep = Platform.pathSeparator;

  String path(String relative) =>
      '${root.path}$sep${relative.replaceAll('/', sep)}';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mollygram_accounts');
    storage = AccountStorage(root.path);
  });

  tearDown(() => root.delete(recursive: true));

  group('prepareActive', () {
    test('creates slot 0 and the index on a fresh install', () async {
      final folders = await storage.prepareActive();

      expect(folders.slot, 0);
      expect(folders.databaseDirectory, path('accounts/0/database'));
      expect(folders.filesDirectory, path('accounts/0/files'));
      expect(Directory(folders.databaseDirectory).existsSync(), isTrue);
      expect(Directory(folders.filesDirectory).existsSync(), isTrue);
      final index = await storage.readIndex();
      expect(index!.active, 0);
      expect(index.accounts.map((a) => a.slot), [0]);
      expect(Directory(path('tdlib')).existsSync(), isFalse);
    });

    test('moves the old tdlib folder in place, keeping its files', () async {
      File(path('tdlib/database/td.binlog'))
        ..createSync(recursive: true)
        ..writeAsStringSync('signed in');
      File(path('tdlib/files/photos/1.jpg'))
        ..createSync(recursive: true)
        ..writeAsStringSync('photo');

      final folders = await storage.prepareActive();

      expect(folders.slot, 0);
      expect(
        File('${folders.databaseDirectory}${sep}td.binlog').readAsStringSync(),
        'signed in',
      );
      expect(
        File(path('accounts/0/files/photos/1.jpg')).readAsStringSync(),
        'photo',
      );
      expect(Directory(path('tdlib')).existsSync(), isFalse);
      expect((await storage.readIndex())!.active, 0);
    });

    test('keeps using the old folder when slot 0 is already taken', () async {
      File(path('tdlib/database/td.binlog'))
        ..createSync(recursive: true)
        ..writeAsStringSync('signed in');
      File(path('accounts/0/database/other'))
        ..createSync(recursive: true)
        ..writeAsStringSync('other');

      final folders = await storage.prepareActive();

      expect(folders.databaseDirectory, path('tdlib/database'));
      expect(File(path('tdlib/database/td.binlog')).existsSync(), isTrue);
      expect(File(path('accounts/0/database/other')).existsSync(), isTrue);
      expect(await storage.readIndex(), isNull);
    });

    test('keeps using the old folder when the move fails', () async {
      if (Platform.isWindows) return;
      File(path('tdlib/database/td.binlog'))
        ..createSync(recursive: true)
        ..writeAsStringSync('signed in');
      // `accounts` as a plain file: the folder can't be created.
      File(path('accounts')).writeAsStringSync('');

      final folders = await storage.prepareActive();

      expect(folders.slot, 0);
      expect(folders.databaseDirectory, path('tdlib/database'));
      expect(File(path('tdlib/database/td.binlog')).existsSync(), isTrue);
    });

    test('is a no-op on later launches', () async {
      await storage.prepareActive();
      File(path('accounts/0/database/td.binlog'))
          .writeAsStringSync('signed in');

      final folders = await storage.prepareActive();

      expect(folders.databaseDirectory, path('accounts/0/database'));
      expect(File(path('accounts/0/database/td.binlog')).existsSync(), isTrue);
    });

    test('rebuilds a lost or broken index from the slot folders', () async {
      Directory(path('accounts/2/database')).createSync(recursive: true);
      Directory(path('accounts/5/database')).createSync(recursive: true);
      File(path('accounts/accounts.json')).writeAsStringSync('{not json');

      final folders = await storage.prepareActive();

      expect(folders.slot, 2);
      final index = await storage.readIndex();
      expect(index!.accounts.map((a) => a.slot), [2, 5]);
    });

    test('opens the active slot named by the index', () async {
      await storage.writeIndex(
        AccountIndex(
          active: 3,
          accounts: const [
            AccountEntry(slot: 0, userId: 42),
            AccountEntry(slot: 3),
          ],
        ),
      );

      final folders = await storage.prepareActive();

      expect(folders.slot, 3);
      expect(folders.keyName, 'mollygram.tdlib.database-key.v1.account-3');
      final index = await storage.readIndex();
      expect(index!.accounts.first.userId, 42);
    });
  });

  group('databaseKeyFor', () {
    test('moves the old key to slot 0', () async {
      final key = base64UrlEncode(List<int>.filled(32, 7));
      final store = _MemoryStore({AccountStorage.legacyKeyName: key});

      final bytes = await databaseKeyFor(0, store);

      expect(bytes, List<int>.filled(32, 7));
      expect(store.values, {AccountStorage.keyNameFor(0): key});
    });

    test('keeps the old key when it cannot be copied', () async {
      final key = base64UrlEncode(List<int>.filled(32, 7));
      final store = _MemoryStore({
        AccountStorage.legacyKeyName: key,
      }, failWrites: true);

      expect(await databaseKeyFor(0, store), List<int>.filled(32, 7));
      expect(store.values, {AccountStorage.legacyKeyName: key});
    });

    test('creates a stable key per slot', () async {
      final store = _MemoryStore({});

      final first = await databaseKeyFor(1, store);
      final again = await databaseKeyFor(1, store);
      final other = await databaseKeyFor(2, store);

      expect(first, hasLength(32));
      expect(again, first);
      expect(other, isNot(first));
      expect(store.values.keys, {
        AccountStorage.keyNameFor(1),
        AccountStorage.keyNameFor(2),
      });
    });

    test('does not hand the old key to another slot', () async {
      final key = base64UrlEncode(List<int>.filled(32, 7));
      final store = _MemoryStore({AccountStorage.legacyKeyName: key});

      expect(await databaseKeyFor(1, store), isNot(List<int>.filled(32, 7)));
      expect(store.values[AccountStorage.legacyKeyName], key);
    });
  });
}

final class _MemoryStore implements SecretStore {
  _MemoryStore(this.values, {this.failWrites = false});

  final Map<String, String> values;
  final bool failWrites;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('keychain locked');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}
