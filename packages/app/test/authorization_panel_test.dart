import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/authorization_panel.dart';
import 'package:mollygram_core/mollygram_core.dart';

void main() {
  Widget panel(AuthorizationStage stage, {ValueChanged<String>? onPhone}) =>
      MaterialApp(
        home: AuthorizationPanel(
          stage: stage,
          submitPhone: onPhone ?? (_) {},
          requestQrCode: () {},
          submitCode: (_) {},
          submitPassword: (_) {},
        ),
      );

  testWidgets('submits a phone number', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      panel(
        AuthorizationStage.phoneNumber(),
        onPhone: (value) => submitted = value,
      ),
    );

    await tester.enterText(find.byType(TextField), '+15550000000');
    await tester.tap(find.text('Continue'));

    expect(submitted, '+15550000000');
  });

  testWidgets('shows the TDLib QR login link', (tester) async {
    await tester.pumpWidget(
      panel(AuthorizationStage.qrCode(link: 'tg://login?token=x')),
    );

    expect(find.text('Scan this QR code'), findsOneWidget);
    expect(find.text('tg://login?token=x'), findsOneWidget);
  });

  testWidgets('renders a password field for two-step verification', (
    tester,
  ) async {
    await tester.pumpWidget(panel(AuthorizationStage.password()));

    expect(find.text('Two-step verification'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
  });
}
