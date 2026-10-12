import 'package:mollygram_core/mollygram_core.dart';
import 'package:test/test.dart';

void main() {
  test('без dart-define ключи считаются не заданными', () {
    expect(TelegramApiConfig.fromEnvironment.isConfigured, isFalse);
  });

  test('api_hash не попадает в toString', () {
    const config = TelegramApiConfig(
      apiId: 12345,
      apiHash: '0123456789abcdef0123456789abcdef',
    );
    expect(config.isConfigured, isTrue);
    expect(config.toString(), isNot(contains('0123456789abcdef')));
  });
}
