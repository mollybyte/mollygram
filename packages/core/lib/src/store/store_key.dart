import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../account_storage.dart';

/// Where the account in [slot] keeps its [MessageStore] file: next to its
/// TDLib folders, `accounts/<slot>/mollygram.db` under [root] (see
/// [AccountStorage]).
String messageStorePathFor(String root, int slot) {
  final sep = Platform.pathSeparator;
  return '$root${sep}accounts$sep$slot${sep}mollygram.db';
}

/// The keychain entry of the store key of the account in [slot], next to
/// its TDLib key ([AccountStorage.keyNameFor]).
String messageStoreKeyNameFor(int slot) =>
    'mollygram.store.database-key.v1.account-$slot';

/// Reads the store key of the account in [slot] from [store], creating a
/// random 256-bit one the first time.
Future<List<int>> messageStoreKeyFor(int slot, SecretStore store) async {
  final name = messageStoreKeyNameFor(slot);
  final stored = await store.read(name);
  if (stored != null) return base64Url.decode(stored);
  final random = Random.secure();
  final key = List<int>.generate(32, (_) => random.nextInt(256));
  await store.write(name, base64UrlEncode(key));
  return key;
}
