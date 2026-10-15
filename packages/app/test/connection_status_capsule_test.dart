import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/session/connection_status_capsule.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  Widget app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
    theme: buildMgTheme(MgColors.light),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Material(child: child),
  );

  Future<void> show(
    WidgetTester tester,
    ConnectionStatus status, {
    Locale locale = const Locale('en'),
  }) => tester.pumpWidget(
    app(ConnectionStatusView(status: status), locale: locale),
  );

  double opacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(ConnectionStatusView),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  const delay = Duration(milliseconds: 800);
  const fade = Duration(milliseconds: 300);

  testWidgets('shows nothing while connected', (tester) async {
    await show(tester, ConnectionStatus.ready);
    await tester.pump(delay * 2);

    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('a quick reconnect never shows', (tester) async {
    await show(tester, ConnectionStatus.connecting);
    await tester.pump(delay ~/ 2);
    await show(tester, ConnectionStatus.ready);
    await tester.pump(delay * 2);

    expect(find.text('Connecting…'), findsNothing);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('appears after the delay and fades out when ready', (
    tester,
  ) async {
    await show(tester, ConnectionStatus.connecting);
    await tester.pump();
    expect(opacity(tester), 0);

    await tester.pump(delay);
    await tester.pump(fade);
    expect(opacity(tester), 1);
    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    await show(tester, ConnectionStatus.updating);
    await tester.pump(fade);
    expect(find.text('Updating…'), findsOneWidget);
    expect(find.text('Connecting…'), findsNothing);

    await show(tester, ConnectionStatus.ready);
    await tester.pump();
    expect(opacity(tester), 0);
    // The last status stays on the capsule while it fades out.
    expect(find.text('Updating…'), findsOneWidget);
    await tester.pump(fade);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('speaks Russian', (tester) async {
    await show(
      tester,
      ConnectionStatus.waitingForNetwork,
      locale: const Locale('ru'),
    );
    await tester.pump(delay);
    await tester.pump(fade);

    expect(find.text('Ожидание сети…'), findsOneWidget);
  });

  testWidgets('follows the session through the provider', (tester) async {
    final statuses = StreamController<ConnectionStatus>();
    addTearDown(statuses.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionStatusProvider.overrideWith((ref) => statuses.stream),
        ],
        child: app(const ConnectionStatusCapsule()),
      ),
    );

    statuses.add(ConnectionStatus.waitingForNetwork);
    await tester.pump();
    await tester.pump(delay);
    await tester.pump(fade);
    expect(find.text('Waiting for network…'), findsOneWidget);

    statuses.add(ConnectionStatus.ready);
    await tester.pump();
    await tester.pump(fade);
    expect(find.text('Waiting for network…'), findsNothing);
  });
}
