import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:path_provider/path_provider.dart';

/// Creates TDLib's desktop paths and keeps its database key in OS secure
/// storage. The key is random, stable across app launches, and never written
/// to the application-support directory.
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

  static const _keyName = 'mollygram.tdlib.database-key.v1';

  final FlutterSecureStorage _secureStorage;

  Future<TdlibParameters> load(TelegramApiConfig api) async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}${Platform.pathSeparator}tdlib');
    final database = Directory('${root.path}${Platform.pathSeparator}database');
    final files = Directory('${root.path}${Platform.pathSeparator}files');
    await Future.wait([
      database.create(recursive: true),
      files.create(recursive: true),
    ]);

    return TdlibParameters(
      api: api,
      databaseDirectory: database.path,
      filesDirectory: files.path,
      databaseEncryptionKey: await _databaseKey(),
      systemLanguageCode: _languageCode(),
      deviceModel: _deviceModel(),
      systemVersion: Platform.operatingSystemVersion,
      applicationVersion: _applicationVersion,
    );
  }

  Future<Uint8List> _databaseKey() async {
    final stored = await _secureStorage.read(key: _keyName);
    if (stored != null) return Uint8List.fromList(base64Url.decode(stored));

    final key = Uint8List.fromList(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    await _secureStorage.write(key: _keyName, value: base64UrlEncode(key));
    return key;
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
