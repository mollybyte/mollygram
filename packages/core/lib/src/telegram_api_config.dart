/// api_id и api_hash приложения Telegram.
///
/// Значения не хранятся в репозитории: они приходят при сборке через
/// `--dart-define-from-file=config/telegram.json` (локально) или из
/// GitHub Secrets (в релизной сборке). Шаблон файла лежит в
/// `config/telegram.example.json`.
final class TelegramApiConfig {
  const TelegramApiConfig({required this.apiId, required this.apiHash});

  /// Значения, переданные при сборке.
  static const TelegramApiConfig fromEnvironment = TelegramApiConfig(
    apiId: int.fromEnvironment('TELEGRAM_API_ID'),
    apiHash: String.fromEnvironment('TELEGRAM_API_HASH'),
  );

  final int apiId;
  final String apiHash;

  /// `false`, если сборка запущена без файла с ключами.
  bool get isConfigured => apiId > 0 && apiHash.length == 32;

  @override
  String toString() =>
      'TelegramApiConfig(apiId: $apiId, apiHash: ${isConfigured ? '***' : 'missing'})';
}
