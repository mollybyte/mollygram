import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('приложение запускается', (tester) async {
    await tester.pumpWidget(const ColoredBox(color: Color(0xFFFFFFFF)));
    expect(find.byType(ColoredBox), findsOneWidget);
  });
}
