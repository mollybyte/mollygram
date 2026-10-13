import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/app.dart';
import 'package:mollygram/src/auth/sign_in_screen.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/session/sign_in_actions.dart';
import 'package:mollygram/src/ui/glass.dart';
import 'package:mollygram/src/ui/theme.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' show TdException;

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
          theme: buildTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GlassSettings(
            blur: false,
            child: Material(child: SignInScreen(stage: stage)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('asks TDLib for a QR code first', (tester) async {
    await pump(tester, const AuthorizationStage.phoneNumber());

    expect(actions.calls, ['qr']);
    expect(find.text('Loading the code…'), findsOneWidget);
    expect(find.text('Sign in with phone number'), findsOneWidget);
  });

  testWidgets('switches to the phone number and submits it', (tester) async {
    await pump(tester, const AuthorizationStage.qrCode(link: 'tg://login?x'));

    await tester.tap(find.text('Sign in with phone number'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' +1 555 0100 ');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(actions.calls, ['phone:+1 555 0100']);
  });

  testWidgets('explains a rejected code', (tester) async {
    actions.failWith = const TdException(400, 'PHONE_CODE_INVALID');
    await pump(tester, const AuthorizationStage.code());

    await tester.enterText(find.byType(TextField), '12345');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(actions.calls, ['code:12345']);
    expect(find.text('This code is not valid.'), findsOneWidget);
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
  Future<void> submitPhone(String phoneNumber) => _call('phone:$phoneNumber');

  @override
  Future<void> submitCode(String code) => _call('code:$code');

  @override
  Future<void> submitPassword(String password) => _call('password');
}
