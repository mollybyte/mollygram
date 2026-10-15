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
/// [MessageCapture] calls it the first time it keeps something. When the
/// file exists but its key is gone, throws [StoreKeyLost] rather than
/// making a new key that can't read it.
final messageStoreOpenerProvider = Provider<MessageStoreOpener>(
  (ref) => () async {
    final location = await ref.read(messageStoreLocationProvider.future);
    final key = await messageStoreKeyFor(
      location.slot,
      ref.read(messageStoreSecretsProvider),
      storeExists: await File(location.path).exists(),
    );
    return MessageStore.open(path: location.path, key: key);
  },
);

/// What the store holds, for the privacy extras page.
final class StoredMessagesStatus {
  const StoredMessagesStatus({
    this.size = 0,
    this.count = 0,
    this.unreadable = false,
  });

  /// Bytes on disk, read from the files.
  final int size;

  /// Deleted messages and versions kept.
  final int count;

  /// The key no longer opens the store: it can only be reset.
  final bool unreadable;
}

/// The store's size and contents. A store that was never written is not
/// created just to look at it; the status follows every write.
final storedMessagesStatusProvider =
    FutureProvider.autoDispose<StoredMessagesStatus>((ref) async {
      final session = await ref.watch(telegramSessionProvider.future);
      final location = await ref.watch(messageStoreLocationProvider.future);
      final capture = session.capture;
      final changes = capture.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      final size = await MessageStore.sizeOnDisk(location.path);
      if (capture.failure is StoreKeyLost) {
        return StoredMessagesStatus(size: size, unreadable: true);
      }
      if (size == 0) return const StoredMessagesStatus();
      final store = capture.store;
      if (store == null) return StoredMessagesStatus(size: size);
      try {
        return StoredMessagesStatus(
          size: size,
          count: await (await store).count(),
        );
      } on StoreKeyLost {
        return StoredMessagesStatus(size: size, unreadable: true);
      }
    });

/// Forgets the deleted messages and edit history kept so far.
final clearStoredMessagesProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final session = await ref.read(telegramSessionProvider.future);
    final store = session.capture.store;
    if (store != null) await (await store).clear();
    ref.invalidate(storedMessagesStatusProvider);
  },
);

/// Deletes a store whose key is lost, and its key: the next thing kept
/// starts a new one.
final resetStoredMessagesProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final session = await ref.read(telegramSessionProvider.future);
    final location = await ref.read(messageStoreLocationProvider.future);
    await session.capture.closeStore();
    await MessageStore.deleteAt(location.path);
    await deleteMessageStoreKey(
      location.slot,
      ref.read(messageStoreSecretsProvider),
    );
    ref.invalidate(storedMessagesStatusProvider);
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
