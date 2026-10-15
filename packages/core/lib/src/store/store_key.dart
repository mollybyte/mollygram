import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../account_storage.dart';
import 'message_store.dart';

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
///
/// When [storeExists] and the key is missing or unreadable, a new key
/// would not open the file: throws [StoreKeyLost] instead.
Future<List<int>> messageStoreKeyFor(
  int slot,
  SecretStore store, {
  bool storeExists = false,
}) async {
  final name = messageStoreKeyNameFor(slot);
  final stored = await store.read(name);
  if (stored != null) {
    try {
      final key = base64Url.decode(stored);
      if (key.length == 32) return key;
    } on FormatException {
      // Treated as lost below.
    }
    if (storeExists) throw const StoreKeyLost();
  } else if (storeExists) {
    throw const StoreKeyLost();
  }
  final random = Random.secure();
  final key = List<int>.generate(32, (_) => random.nextInt(256));
  await store.write(name, base64UrlEncode(key));
  return key;
}

/// Forgets the store key of the account in [slot], for a reset.
Future<void> deleteMessageStoreKey(int slot, SecretStore store) =>
    store.delete(messageStoreKeyNameFor(slot));
