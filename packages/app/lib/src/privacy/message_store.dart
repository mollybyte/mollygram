import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:path_provider/path_provider.dart';

import '../session/providers.dart';

/// Where the active account keeps its [MessageStore], and its slot.
final class MessageStoreLocation {
  const MessageStoreLocation({required this.slot, required this.path});

  final int slot;
  final String path;
}

/// `accounts/<slot>/mollygram.db` of the active account, next to its TDLib
/// folders.
final messageStoreLocationProvider = FutureProvider<MessageStoreLocation>((
  ref,
) async {
  final support = await getApplicationSupportDirectory();
  final index = await AccountStorage(support.path).readIndex();
  final slot = index?.active ?? 0;
  return MessageStoreLocation(
    slot: slot,
    path: messageStorePathFor(support.path, slot),
  );
});

/// The keychain, where the store key lives next to the TDLib key.
final messageStoreSecretsProvider = Provider<SecretStore>(
  (ref) => const _KeychainStore(
    FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  ),
);

/// Opens the active account's store with its key; the session's
/// [MessageCapture] calls it the first time it keeps something.
final messageStoreOpenerProvider = Provider<MessageStoreOpener>(
  (ref) => () async {
    final location = await ref.read(messageStoreLocationProvider.future);
    final key = await messageStoreKeyFor(
      location.slot,
      ref.read(messageStoreSecretsProvider),
    );
    return MessageStore.open(path: location.path, key: key);
  },
);

/// How much the store takes on disk, for the privacy extras page. A store
/// that was never written is not created just to measure it.
final storedMessagesSizeProvider = FutureProvider.autoDispose<int>((ref) async {
  final session = await ref.watch(telegramSessionProvider.future);
  final location = await ref.watch(messageStoreLocationProvider.future);
  if (!await File(location.path).exists()) return 0;
  final store = session.capture.store;
  if (store == null) return 0;
  return (await store).sizeInBytes();
});

/// Forgets the deleted messages and edit history kept so far.
final clearStoredMessagesProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final session = await ref.read(telegramSessionProvider.future);
    final store = session.capture.store;
    if (store != null) await (await store).clear();
    ref.invalidate(storedMessagesSizeProvider);
  },
);

final class _KeychainStore implements SecretStore {
  const _KeychainStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
