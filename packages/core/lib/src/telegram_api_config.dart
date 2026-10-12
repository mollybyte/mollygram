/// The Telegram application's api_id and api_hash.
///
/// The values are not stored in the repository: they are supplied at build
/// time via `--dart-define-from-file=config/telegram.json` (locally) or from
/// GitHub Secrets (in release builds). A template for the file lives in
/// `config/telegram.example.json`.
final class TelegramApiConfig {
  const TelegramApiConfig({required this.apiId, required this.apiHash});

  /// The values passed in at build time.
  static const TelegramApiConfig fromEnvironment = TelegramApiConfig(
    apiId: int.fromEnvironment('TELEGRAM_API_ID'),
    apiHash: String.fromEnvironment('TELEGRAM_API_HASH'),
  );

  final int apiId;
  final String apiHash;

  /// Whether the keys were provided; `false` if built without the keys file.
  bool get isConfigured => apiId > 0 && apiHash.length == 32;

  @override
  String toString() =>
      'TelegramApiConfig(apiId: $apiId, apiHash: ${isConfigured ? '***' : 'missing'})';
}
