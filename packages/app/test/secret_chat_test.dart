import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/secret/secret_chat.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  final chatId = SecretChatsController.chatIdOf(5);
  final en = lookupAppLocalizations(const Locale('en'));
  final ru = lookupAppLocalizations(const Locale('ru'));

  SecretChatInfo chat(
    SecretChatStatus status, {
    bool outbound = true,
    Uint8List? hash,
  }) => SecretChatInfo(
    id: 5,
    userId: 7,
    status: status,
    isOutbound: outbound,
    keyHash: hash ?? Uint8List(0),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required SecretChatInfo? info,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secretChatProvider(chatId).overrideWith((ref) => Stream.value(info)),
        ],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(child: Center(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('a status line for each state', () {
    expect(
      secretChatStatusText(chat(SecretChatStatus.pending), 'Anna', en),
      'Waiting for Anna to come online',
    );
    expect(
      secretChatStatusText(
        chat(SecretChatStatus.pending, outbound: false),
        'Anna',
        en,
      ),
      'Exchanging encryption keys',
    );
    expect(secretChatStatusText(chat(SecretChatStatus.ready), 'A', en), null);
    expect(
      secretChatStatusText(chat(SecretChatStatus.closed), 'Anna', ru),
      'Секретный чат закрыт',
    );
  });

  test('self-destruct times read naturally in both languages', () {
    String label(int s, AppLocalizations l10n) => selfDestructLabel(s, l10n);
    expect(label(0, en), 'Off');
    expect(label(1, en), '1 second');
    expect(label(30, en), '30 seconds');
    expect(label(60, en), '1 minute');
    expect(label(3600, en), '1 hour');
    expect(label(86400, en), '1 day');
    expect(label(604800, en), '1 week');
    expect(label(2, ru), '2 секунды');
    expect(label(5, ru), '5 секунд');
    expect(label(604800, ru), '1 неделя');
    for (final t in SecretChatsController.selfDestructTimes) {
      expect(label(t, ru), isNotEmpty);
    }
  });

  testWidgets('the key sheet shows the picture, the hex and whose to '
      'compare with', (tester) async {
    final hash = Uint8List.fromList(List.generate(36, (i) => i * 7));
    await pump(
      tester,
      SecretKeySheet(chatId: chatId, name: 'Anna'),
      info: chat(SecretChatStatus.ready, hash: hash),
    );

    expect(find.text('Encryption key'), findsOneWidget);
    expect(find.byType(SecretKeyPicture), findsOneWidget);
    final hex = SecretKeyImage.hex(hash);
    expect(find.text(hex.take(8).join('  ')), findsOneWidget);
    expect(find.textContaining("on Anna's device"), findsOneWidget);
  });

  testWidgets('before the key exchange there is no picture yet', (
    tester,
  ) async {
    await pump(
      tester,
      SecretKeySheet(chatId: chatId, name: 'Anna'),
      info: chat(SecretChatStatus.pending),
    );

    expect(find.byType(SecretKeyPicture), findsNothing);
    expect(
      find.text(
        "The key appears once the other person's app accepts the chat.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('no closed bar while the chat works', (tester) async {
    await pump(
      tester,
      SecretChatClosedBar(chatId: chatId),
      info: chat(SecretChatStatus.ready),
    );
    expect(find.text('Secret chat closed'), findsNothing);
  });

  testWidgets('a closed chat offers to delete it', (tester) async {
    await pump(
      tester,
      SecretChatClosedBar(chatId: chatId),
      info: chat(SecretChatStatus.closed),
    );
    expect(find.text('Secret chat closed'), findsOneWidget);
    expect(find.byKey(const ValueKey('deleteSecretChat')), findsOneWidget);
  });

  test('the info panel row: start one, or show the key in one', () {
    expect(secretChatActionLabel(7, en), 'Start secret chat');
    expect(secretChatActionLabel(chatId, en), 'Encryption key');
  });
}
