import 'dart:typed_data';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'telegram_api_config.dart';

/// Immutable, platform-supplied settings used for TDLib's first start.
///
/// The database encryption key is deliberately injected by the platform layer.
/// It must come from the operating system's secure storage and is never
/// persisted, logged, or derived from Telegram API credentials.
final class TdlibParameters {
  TdlibParameters({
    required this.api,
    required this.databaseDirectory,
    required this.filesDirectory,
    required Uint8List databaseEncryptionKey,
    required this.systemLanguageCode,
    required this.deviceModel,
    required this.applicationVersion,
    this.systemVersion = '',
    this.useTestDc = false,
  }) : databaseEncryptionKey = Uint8List.fromList(databaseEncryptionKey) {
    if (databaseDirectory.isEmpty || filesDirectory.isEmpty) {
      throw ArgumentError('TDLib database and files directories must be set.');
    }
    if (this.databaseEncryptionKey.isEmpty) {
      throw ArgumentError('TDLib database encryption key must not be empty.');
    }
    if (systemLanguageCode.isEmpty ||
        deviceModel.isEmpty ||
        applicationVersion.isEmpty) {
      throw ArgumentError(
        'TDLib system and application information must be set.',
      );
    }
  }

  final TelegramApiConfig api;
  final String databaseDirectory;
  final String filesDirectory;
  final Uint8List databaseEncryptionKey;
  final String systemLanguageCode;
  final String deviceModel;
  final String systemVersion;
  final String applicationVersion;
  final bool useTestDc;
}

/// Sends TDLib's one-time initialization request for an account client.
///
/// Call this only after TDLib reports
/// [td.AuthorizationStateWaitTdlibParameters]. Repeated calls are safe and
/// don't send a second request.
final class TdlibInitializer {
  TdlibInitializer(this._client, {required this.parameters});

  final td.TdClient _client;
  final TdlibParameters parameters;
  Future<void>? _initializing;

  Future<void> initialize() {
    if (!parameters.api.isConfigured) {
      return Future<void>.error(
        StateError('Telegram API credentials have not been configured.'),
      );
    }
    return _initializing ??= _sendParameters();
  }

  Future<void> _sendParameters() async {
    await _client.send(
      td.SetTdlibParameters(
        useTestDc: parameters.useTestDc,
        databaseDirectory: parameters.databaseDirectory,
        filesDirectory: parameters.filesDirectory,
        databaseEncryptionKey: parameters.databaseEncryptionKey,
        useFileDatabase: true,
        useChatInfoDatabase: true,
        useMessageDatabase: true,
        useSecretChats: true,
        apiId: parameters.api.apiId,
        apiHash: parameters.api.apiHash,
        systemLanguageCode: parameters.systemLanguageCode,
        deviceModel: parameters.deviceModel,
        systemVersion: parameters.systemVersion,
        applicationVersion: parameters.applicationVersion,
      ),
    );
  }
}
