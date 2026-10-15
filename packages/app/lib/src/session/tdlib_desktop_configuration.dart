import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:path_provider/path_provider.dart';

/// Prepares the active account's TDLib folders (see [AccountStorage]) and
/// keeps its database key in OS secure storage. The key is random, stable
/// across app launches, and never written to the application-support
/// directory.
final class TdlibDesktopConfiguration {
  TdlibDesktopConfiguration({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  static const _applicationVersion = String.fromEnvironment(
    'MOLLYGRAM_VERSION',
    defaultValue: '0.1.0',
  );

  final FlutterSecureStorage _secureStorage;

  Future<TdlibParameters> load(TelegramApiConfig api) async {
    final support = await getApplicationSupportDirectory();
    final account = await AccountStorage(support.path).prepareActive();
    final key = await databaseKeyFor(
      account.slot,
      _KeychainStore(_secureStorage),
    );

    return TdlibParameters(
      api: api,
      databaseDirectory: account.databaseDirectory,
      filesDirectory: account.filesDirectory,
      databaseEncryptionKey: Uint8List.fromList(key),
      systemLanguageCode: _languageCode(),
      deviceModel: _deviceModel(),
      systemVersion: Platform.operatingSystemVersion,
      applicationVersion: _applicationVersion,
    );
  }

  /// What Telegram shows in the active sessions list.
  String _deviceModel() {
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isWindows) return 'PC';
    return 'Linux';
  }

  String _languageCode() {
    final language = Platform.localeName.split(RegExp('[-_]')).first;
    return language.isEmpty ? 'en' : language;
  }
}

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
