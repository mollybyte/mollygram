import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'store/store_key.dart';

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

  /// Every keychain entry of the account in [slot]: its TDLib key and the
  /// key of its encrypted message store.
  static List<String> secretNamesFor(int slot) => [
    keyNameFor(slot),
    messageStoreKeyNameFor(slot),
  ];

  /// As many accounts as the official apps allow without Premium.
  static const maxAccounts = 3;

  static final _sep = Platform.pathSeparator;

  String get _accounts => '$root${_sep}accounts';
  String get _legacy => '$root${_sep}tdlib';
  String get _indexPath => '$_accounts${_sep}accounts.json';
  String _slotPath(int slot) => '$_accounts$_sep$slot';

  /// The folder of the account in [slot], where everything it keeps lives.
  String slotPath(int slot) => _slotPath(slot);

  /// Prepares the active account's folders, moving the old single-account
  /// folder first when there is one.
  Future<AccountFolders> prepareActive() async {
    var index = await readIndex();
    if (index == null) {
      if (!await _moveLegacy()) return _create(0, _legacy);
      final broken = File(_indexPath);
      // A broken index is kept aside; the rebuilt one can't tell who was
      // signed in, so its entries are marked as recovered.
      final recovered = await broken.exists();
      if (recovered) {
        await broken
            .copy('$_indexPath.broken')
            .catchError((Object _) => broken);
      }
      index = await _indexFromDisk(recovered: recovered);
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

  Future<AccountIndex> _indexFromDisk({bool recovered = false}) async {
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
      accounts: [
        for (final slot in slots)
          AccountEntry(slot: slot, recovered: recovered),
      ],
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

  /// The index, after [prepareActive] has made sure there is one. While
  /// the old single-account folder is still in use (it could not be
  /// moved), the index is [AccountIndex.legacy]: one account, which can't
  /// be removed and next to which none can be added.
  Future<AccountIndex> index() async {
    final index = await readIndex();
    if (index != null) return index;
    final folders = await prepareActive();
    if (folders.databaseDirectory.startsWith(_legacy + _sep)) {
      return AccountIndex(
        active: 0,
        accounts: const [AccountEntry(slot: 0, recovered: true)],
        legacy: true,
      );
    }
    return await readIndex() ?? await _indexFromDisk();
  }

  /// Deletes what removed accounts left behind when the app stopped
  /// between writing the index and deleting their folder: folders and
  /// keychain entries of slots below [AccountIndex.nextSlot] that the
  /// index no longer lists.
  Future<void> cleanUp(SecretStore secrets) async {
    final index = await readIndex();
    if (index == null) return;
    final listed = {for (final account in index.accounts) account.slot};
    for (var slot = 0; slot < index.nextSlot; slot++) {
      if (listed.contains(slot)) continue;
      final folder = Directory(_slotPath(slot));
      final hadFolder = await folder.exists();
      if (hadFolder) await folder.delete(recursive: true);
      // Keys go with the folder, or alone for the last few slots, which
      // may have lost only their keys' removal.
      if (hadFolder || slot >= index.nextSlot - maxAccounts) {
        for (final name in secretNamesFor(slot)) {
          await secrets.delete(name);
        }
      }
    }
  }

  /// Adds a slot for another account and makes it the active one. Slot
  /// numbers are never reused, so nothing of a removed account is found
  /// by a new one.
  Future<AccountIndex> addAccount() async {
    final index = await this.index();
    if (index.legacy) throw StateError('The old account folder is in use');
    if (index.accounts.length >= maxAccounts) {
      throw StateError('At most $maxAccounts accounts');
    }
    final slot = index.nextSlot;
    final next = AccountIndex(
      active: slot,
      accounts: [
        ...index.accounts,
        AccountEntry(slot: slot),
      ],
      nextSlot: slot + 1,
    );
    await writeIndex(next);
    return next;
  }

  /// Makes [slot] the account that opens.
  Future<AccountIndex> activate(int slot) async {
    final index = await this.index();
    final next = AccountIndex(
      active: slot,
      accounts: index.accounts,
      nextSlot: index.nextSlot,
    );
    await writeIndex(next);
    return next;
  }

  /// Notes who is signed in to [slot], for the account list while another
  /// account is open.
  Future<AccountIndex> describe(AccountEntry entry) async {
    final index = await this.index();
    if (!index.accounts.any((a) => a.slot == entry.slot)) return index;
    final next = AccountIndex(
      active: index.active,
      accounts: [
        for (final account in index.accounts)
          account.slot == entry.slot ? entry : account,
      ],
      nextSlot: index.nextSlot,
    );
    await writeIndex(next);
    return next;
  }

  /// Forgets the account in [slot]: its folder (TDLib data, files, the
  /// message store, the window layout) and its keychain entries in
  /// [secrets]. When it was the active one, the first remaining account
  /// becomes active; when it was the last, a new empty slot takes its
  /// place. The TDLib client of the slot must be closed first.
  Future<AccountIndex> remove(int slot, SecretStore secrets) async {
    final index = await this.index();
    if (index.legacy) throw StateError('The old account folder is in use');
    final rest = [
      for (final account in index.accounts)
        if (account.slot != slot) account,
    ];
    var nextSlot = index.nextSlot;
    final AccountIndex next;
    if (rest.isEmpty) {
      next = AccountIndex(
        active: nextSlot,
        accounts: [AccountEntry(slot: nextSlot)],
        nextSlot: nextSlot + 1,
      );
      nextSlot++;
    } else {
      next = AccountIndex(
        active: index.active == slot ? rest.first.slot : index.active,
        accounts: rest,
        nextSlot: nextSlot,
      );
    }
    // The index first: should deleting fail halfway, the slot is no longer
    // opened, and its number is never handed out again.
    await writeIndex(next);
    final folder = Directory(_slotPath(slot));
    if (await folder.exists()) await folder.delete(recursive: true);
    for (final name in secretNamesFor(slot)) {
      await secrets.delete(name);
    }
    return next;
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
  AccountIndex({
    required this.active,
    required this.accounts,
    int? nextSlot,
    this.legacy = false,
  }) : nextSlot =
           nextSlot ??
           accounts.fold<int>(0, (n, a) => a.slot >= n ? a.slot + 1 : n) {
    if (!accounts.any((account) => account.slot == active)) {
      throw ArgumentError.value(active, 'active', 'is not in the index');
    }
    if (accounts.any((account) => account.slot >= this.nextSlot)) {
      throw ArgumentError.value(nextSlot, 'nextSlot', 'is already used');
    }
  }

  static const version = 1;

  final int active;
  final List<AccountEntry> accounts;

  /// The slot the next added account gets.
  final int nextSlot;

  /// The old single-account folder is still in use: accounts can't be
  /// added or removed. Never written to disk.
  final bool legacy;

  AccountEntry get activeAccount =>
      accounts.firstWhere((account) => account.slot == active);

  static AccountIndex fromJson(Object? json) {
    if (json case {
      'version': version,
      'active': final int active,
      'accounts': final List<Object?> accounts,
    }) {
      final entries = [
        for (final entry in accounts) AccountEntry.fromJson(entry),
      ];
      final next = json['next_slot'];
      final used = entries.fold<int>(0, (n, a) => a.slot >= n ? a.slot + 1 : n);
      return AccountIndex(
        active: active,
        accounts: entries,
        nextSlot: next is int && next >= used ? next : used,
      );
    }
    throw const FormatException('Not an accounts index');
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'active': active,
    'accounts': [for (final account in accounts) account.toJson()],
    'next_slot': nextSlot,
  };
}

final class AccountEntry {
  const AccountEntry({
    required this.slot,
    this.userId,
    this.name = '',
    this.phoneNumber = '',
    this.recovered = false,
  });

  final int slot;

  /// Rebuilt from its folder after the index was lost: whether it is
  /// signed in is unknown until it is opened.
  final bool recovered;

  /// Whether the account may be signed in on Telegram's side, so leaving
  /// it needs a real log out.
  bool get maybeSignedIn => isSignedIn || recovered;

  /// The Telegram user id, known once the account has signed in.
  final int? userId;

  /// The name and phone number as last seen, for the account list while
  /// another account is open.
  final String name;
  final String phoneNumber;

  /// Whether the account has ever finished signing in.
  bool get isSignedIn => userId != null;

  static AccountEntry fromJson(Object? json) {
    if (json case {'slot': final int slot}) {
      final userId = json['user_id'];
      final name = json['name'];
      final phone = json['phone_number'];
      return AccountEntry(
        slot: slot,
        userId: userId is int ? userId : null,
        name: name is String ? name : '',
        phoneNumber: phone is String ? phone : '',
        recovered: json['recovered'] == true,
      );
    }
    throw const FormatException('Not an account entry');
  }

  Map<String, Object?> toJson() => {
    'slot': slot,
    if (userId != null) 'user_id': userId,
    if (name.isNotEmpty) 'name': name,
    if (phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
    if (recovered) 'recovered': true,
  };

  @override
  bool operator ==(Object other) =>
      other is AccountEntry &&
      other.slot == slot &&
      other.userId == userId &&
      other.name == name &&
      other.phoneNumber == phoneNumber &&
      other.recovered == recovered;

  @override
  int get hashCode => Object.hash(slot, userId, name, phoneNumber, recovered);
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
