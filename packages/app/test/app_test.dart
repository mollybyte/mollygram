import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/mollygram.dart';
import 'package:mollygram_core/mollygram_core.dart';

void main() {
  testWidgets('starts with the proven prototype shell', (tester) async {
    await tester.pumpWidget(
      const MollygramApp(config: TelegramApiConfig(apiId: 0, apiHash: '')),
    );
    await tester.pump();

    expect(find.text('Anna Morris'), findsWidgets);
    expect(find.text('Message'), findsOneWidget);
  });
}
