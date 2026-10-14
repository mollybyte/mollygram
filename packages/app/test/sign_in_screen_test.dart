import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/app.dart';
import 'package:mollygram/src/auth/sign_in_screen.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/session/sign_in_actions.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' show TdException;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  late _FakeActions actions;

  setUp(() => actions = _FakeActions());

  Future<void> pump(
    WidgetTester tester,
    AuthorizationStage stage, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [signInActionsProvider.overrideWithValue(actions)],
        child: MaterialApp(
          locale: locale,
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: SignInScreen(key: ValueKey(stage.kind), stage: stage),
          ),
        ),
      ),
    );
    // The QR spinner never settles, so pump a fixed time.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('asks TDLib for a QR code first', (tester) async {
    await pump(tester, const AuthorizationStage.phoneNumber());

    expect(actions.calls, ['qr']);
    expect(find.text('Log in to Mollygram by QR code'), findsOneWidget);
    expect(find.text('Log in by phone number'), findsOneWidget);
  });

  testWidgets('leaves the QR step by restarting into the phone form', (
    tester,
  ) async {
    await pump(tester, const AuthorizationStage.qrCode(link: 'tg://login?x'));

    await tester.tap(find.text('Log in by phone number'));
    await tester.pump();
    expect(actions.calls, ['leaveQr']);

    // The restarted session starts at the phone number step; the screen
    // opens on the form and doesn't ask for a new QR code.
    await pump(tester, const AuthorizationStage.phoneNumber());
    await tester.pumpAndSettle();
    expect(find.text('Your phone number'), findsOneWidget);
    expect(actions.calls, ['leaveQr']);
  });

  testWidgets('submits the phone number with the detected country code', (
    tester,
  ) async {
    await pump(tester, const AuthorizationStage.phoneNumber());

    await tester.tap(find.text('Log in by phone number'));
    await tester.pumpAndSettle();
    expect(find.text('Russia'), findsOneWidget);
    expect(find.text('+7'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '900 123-45-67');
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(actions.calls, ['qr', 'phone:+79001234567']);
  });

  testWidgets('picks a country from the list', (tester) async {
    await pump(tester, const AuthorizationStage.phoneNumber());
    await tester.tap(find.text('Log in by phone number'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Russia'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'united');
    await tester.pumpAndSettle();
    await tester.tap(find.text('United States'));
    await tester.pumpAndSettle();

    expect(find.text('United States'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('explains a rejected code', (tester) async {
    actions.failWith = const TdException(400, 'PHONE_CODE_INVALID');
    await pump(
      tester,
      const AuthorizationStage.code(
        phoneNumber: '+7 900 123 45 67',
        delivery: CodeDelivery.app,
      ),
    );
    expect(find.text('+7 900 123 45 67'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12345');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(actions.calls, ['code:12345']);
    expect(find.text('Invalid code'), findsOneWidget);
  });

  testWidgets('shows the password hint in Russian', (tester) async {
    await pump(
      tester,
      const AuthorizationStage.password(hint: 'кот'),
      locale: const Locale('ru'),
    );

    expect(find.text('Двухэтапная проверка'), findsOneWidget);
    expect(
      find.text('Аккаунт защищён дополнительным паролем. Подсказка: кот'),
      findsOneWidget,
    );
  });

  testWidgets('says when the build has no API keys', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telegramApiConfigProvider.overrideWithValue(
            const TelegramApiConfig(apiId: 0, apiHash: ''),
          ),
        ],
        child: const MollygramApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Telegram API keys are missing'), findsOneWidget);
  });
}

final class _FakeActions implements SignInActions {
  final calls = <String>[];
  Object? failWith;

  Future<void> _call(String name) async {
    calls.add(name);
    if (failWith case final error?) throw error;
  }

  @override
  Future<void> requestQrCode() => _call('qr');

  @override
  Future<void> leaveQrCode() => _call('leaveQr');

  @override
  Future<void> submitPhone(String phoneNumber) => _call('phone:$phoneNumber');

  @override
  Future<void> submitCode(String code) => _call('code:$code');

  @override
  Future<void> submitPassword(String password) => _call('password');

  @override
  Future<List<PhoneCountry>> countries() async => const [
    PhoneCountry(code: 'RU', name: 'Russia', callingCodes: ['7']),
    PhoneCountry(code: 'US', name: 'United States', callingCodes: ['1']),
  ];

  @override
  Future<String> currentCountryCode() async => 'RU';
}
