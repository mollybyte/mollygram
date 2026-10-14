import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/session/telegram_session_launcher.dart';
import 'package:mollygram_core/mollygram_core.dart';

void main() {
  test('does not open TDLib without API credentials', () async {
    var opened = false;
    final launcher = TelegramSessionLauncher(
      startTdlib: (_) async {
        opened = true;
        throw UnimplementedError();
      },
    );

    await expectLater(
      launcher.start(const TelegramApiConfig(apiId: 0, apiHash: '')),
      throwsStateError,
    );
    expect(opened, isFalse);
  });
}
