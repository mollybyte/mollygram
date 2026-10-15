import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Where one account keeps its TDLib data, and the name of its database
/// key in the system keychain.
final class AccountFolders {
  const AccountFolders({
    required this.slot,
    required this.databaseDirectory,
    required this.filesDirectory,
  });

  /// The account's local slot: a number given when the account is added,
  /// before its Telegram user id is known, and never reused for another
  /// account.
  final int slot;
  final String databaseDirectory;
  final String filesDirectory;

  String get keyName => AccountStorage.keyNameFor(slot);
}

/// Lays out TDLib data per account under the application support folder:
///
/// ```
/// accounts/accounts.json   the index: slots and the active one
/// accounts/<slot>/database
/// accounts/<slot>/files
/// ```
///
/// Versions before this layout kept the one account in `tdlib/`. The first
/// launch moves that folder to `accounts/0` in place (a rename, so nothing
/// is copied or deleted) and the signed-in user stays signed in. When the
/// move fails, the old folder keeps being used and the move is tried again
/// on the next launch.
final class AccountStorage {
  AccountStorage(this.root);

  /// The application support folder.
  final String root;

  /// The keychain entry of the database key before keys were per account.
  static const legacyKeyName = 'mollygram.tdlib.database-key.v1';

  static String keyNameFor(int slot) =>
      'mollygram.tdlib.database-key.v1.account-$slot';

  static final _sep = Platform.pathSeparator;

  String get _accounts => '$root${_sep}accounts';
  String get _legacy => '$root${_sep}tdlib';
  String get _indexPath => '$_accounts${_sep}accounts.json';
  String _slotPath(int slot) => '$_accounts$_sep$slot';

  /// Prepares the active account's folders, moving the old single-account
  /// folder first when there is one.
  Future<AccountFolders> prepareActive() async {
    var index = await readIndex();
    if (index == null) {
      if (!await _moveLegacy()) return _create(0, _legacy);
      index = await _indexFromDisk();
      // When the index can't be written it is rebuilt from the folders on
      // the next launch, so this is not fatal.
      await writeIndex(index).catchError((Object _) {});
    }
    return _create(index.active, _slotPath(index.active));
  }

  /// Moves `tdlib/` to `accounts/0`. Returns false when the old folder is
  /// still the one to use.
  Future<bool> _moveLegacy() async {
    final legacy = Directory(_legacy);
    if (!await legacy.exists()) return true;
    final target = Directory(_slotPath(0));
    // Never move over a folder that is already there: the old one has the
    // signed-in account and stays in use until this is sorted out.
    if (await target.exists()) return false;
    try {
      await Directory(_accounts).create(recursive: true);
      await legacy.rename(target.path);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  Future<AccountIndex> _indexFromDisk() async {
    final slots = <int>[];
    final accounts = Directory(_accounts);
    if (await accounts.exists()) {
      await for (final entry in accounts.list()) {
        if (entry is! Directory) continue;
        final slot = int.tryParse(entry.path.split(_sep).last);
        if (slot != null && slot >= 0) slots.add(slot);
      }
    }
    if (slots.isEmpty) slots.add(0);
    slots.sort();
    return AccountIndex(
      active: slots.first,
      accounts: [for (final slot in slots) AccountEntry(slot: slot)],
    );
  }

  Future<AccountFolders> _create(int slot, String path) async {
    final folders = AccountFolders(
      slot: slot,
      databaseDirectory: '$path${_sep}database',
      filesDirectory: '$path${_sep}files',
    );
    await Future.wait([
      Directory(folders.databaseDirectory).create(recursive: true),
      Directory(folders.filesDirectory).create(recursive: true),
    ]);
    return folders;
  }

  /// The index, or null when there is none or it can't be read.
  Future<AccountIndex?> readIndex() async {
    try {
      final text = await File(_indexPath).readAsString();
      return AccountIndex.fromJson(jsonDecode(text));
    } on Object {
      return null;
    }
  }

  /// Writes the index through a temporary file, so a crash leaves either
  /// the old index or the new one.
  Future<void> writeIndex(AccountIndex index) async {
    await Directory(_accounts).create(recursive: true);
    final temporary = File('$_indexPath.tmp');
    await temporary.writeAsString(jsonEncode(index.toJson()), flush: true);
    await temporary.rename(_indexPath);
  }
}

/// The accounts index file.
final class AccountIndex {
  AccountIndex({required this.active, required this.accounts}) {
    if (!accounts.any((account) => account.slot == active)) {
      throw ArgumentError.value(active, 'active', 'is not in the index');
    }
  }

  static const version = 1;

  final int active;
  final List<AccountEntry> accounts;

  static AccountIndex fromJson(Object? json) {
    if (json case {
      'version': version,
      'active': final int active,
      'accounts': final List<Object?> accounts,
    }) {
      return AccountIndex(
        active: active,
        accounts: [for (final entry in accounts) AccountEntry.fromJson(entry)],
      );
    }
    throw const FormatException('Not an accounts index');
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'active': active,
    'accounts': [for (final account in accounts) account.toJson()],
  };
}

final class AccountEntry {
  const AccountEntry({required this.slot, this.userId});

  final int slot;

  /// The Telegram user id, known once the account has signed in.
  final int? userId;

  static AccountEntry fromJson(Object? json) {
    if (json case {'slot': final int slot}) {
      final userId = json['user_id'];
      return AccountEntry(slot: slot, userId: userId is int ? userId : null);
    }
    throw const FormatException('Not an account entry');
  }

  Map<String, Object?> toJson() => {
    'slot': slot,
    if (userId != null) 'user_id': userId,
  };
}

/// The few keychain operations the database key needs.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Reads the database key of the account in [slot] from [store], creating a
/// random one the first time.
///
/// Slot 0 takes over the key from before keys were per account: it is
/// copied to the new name and the old entry removed only once the copy
/// reads back. When copying fails the old key is still returned, so the
/// database keeps opening.
Future<List<int>> databaseKeyFor(int slot, SecretStore store) async {
  final name = AccountStorage.keyNameFor(slot);
  final stored = await store.read(name);
  if (stored != null) return base64Url.decode(stored);

  if (slot == 0) {
    final legacy = await store.read(AccountStorage.legacyKeyName);
    if (legacy != null) {
      try {
        await store.write(name, legacy);
        if (await store.read(name) == legacy) {
          await store.delete(AccountStorage.legacyKeyName);
        }
      } on Object {
        // Keep using the old entry; the copy is tried again next launch.
      }
      return base64Url.decode(legacy);
    }
  }

  final random = Random.secure();
  final key = List<int>.generate(32, (_) => random.nextInt(256));
  await store.write(name, base64UrlEncode(key));
  return key;
}
