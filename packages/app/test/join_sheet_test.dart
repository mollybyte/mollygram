import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/links/join_sheet.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  JoinSheetResult? opened;
  var closed = false;
  late int joins;

  setUp(() {
    opened = null;
    closed = false;
    joins = 0;
  });

  Future<void> open(
    WidgetTester tester,
    ChatJoinPreview preview,
    JoinResult result, {
    Future<void>? until,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              opened = await showJoinSheet(
                context,
                preview: preview,
                join: () async {
                  joins++;
                  await until;
                  return result;
                },
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('joins a channel and opens it', (tester) async {
    await open(
      tester,
      const ChatJoinPreview(
        title: 'Daily news',
        isChannel: true,
        chatId: 8,
        username: 'news',
        memberCount: 1200,
        description: 'Headlines every morning',
      ),
      const ChatJoined(8),
    );
    expect(find.text('Daily news'), findsOneWidget);
    expect(find.text('@news · 1,200 subscribers'), findsOneWidget);
    expect(find.text('Headlines every morning'), findsOneWidget);
    expect(find.text('View channel'), findsOneWidget);

    await tester.tap(find.text('Join channel'));
    await tester.pumpAndSettle();
    expect(joins, 1);
    expect(closed, isTrue);
    expect(opened, (chatId: 8, joined: true));
  });

  testWidgets('opens a public chat without joining', (tester) async {
    await open(
      tester,
      const ChatJoinPreview(title: 'Talk', isChannel: false, chatId: 5),
      const ChatJoined(5),
    );
    await tester.tap(find.text('View group'));
    await tester.pumpAndSettle();
    expect(joins, 0);
    expect(opened, (chatId: 5, joined: false));
  });

  testWidgets('a private invite can only be joined', (tester) async {
    await open(
      tester,
      const ChatJoinPreview(
        title: 'Book club',
        isChannel: false,
        inviteLink: 'https://t.me/+abc',
        memberCount: 1,
      ),
      const JoinFailed('INVITE_HASH_EXPIRED'),
    );
    expect(find.text('1 member'), findsOneWidget);
    expect(find.text('View group'), findsNothing);

    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't join. Try again later."), findsOneWidget);
    expect(closed, isFalse);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(opened, isNull);
  });

  testWidgets('a join request waits for the admins', (tester) async {
    await open(
      tester,
      const ChatJoinPreview(
        title: 'Book club',
        isChannel: false,
        inviteLink: 'https://t.me/+abc',
        createsJoinRequest: true,
      ),
      const JoinRequestSent(),
    );
    expect(find.text('An admin has to approve your request.'), findsOneWidget);

    await tester.tap(find.text('Request to join'));
    await tester.pumpAndSettle();
    expect(find.text('Request sent'), findsOneWidget);
    expect(find.text("You'll join once an admin approves it."), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(opened, isNull);
  });

  testWidgets('stays open while the join is on its way', (tester) async {
    final answer = Completer<void>();
    await open(
      tester,
      const ChatJoinPreview(title: 'Talk', isChannel: false, chatId: 5),
      const ChatJoined(5),
      until: answer.future,
    );
    await tester.tap(find.text('Join group'));
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(closed, isFalse);
    expect(find.text('Talk'), findsOneWidget);

    answer.complete();
    await tester.pumpAndSettle();
    expect(opened, (chatId: 5, joined: true));
  });

  group('join bar', () {
    Future<void> bar(WidgetTester tester, JoinResult result) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: Center(
              child: SizedBox(
                width: 400,
                child: JoinBar(
                  preview: const ChatJoinPreview(
                    title: 'News',
                    isChannel: true,
                    chatId: 8,
                  ),
                  join: () async {
                    joins++;
                    return result;
                  },
                  onDone: () => closed = true,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('joins and goes away', (tester) async {
      await bar(tester, const ChatJoined(8));
      await tester.tap(find.text('Join channel'));
      await tester.pump();
      expect(joins, 1);
      expect(closed, isTrue);
    });

    testWidgets('says when joining failed and can be closed', (tester) async {
      await bar(tester, const JoinFailed('CHANNELS_TOO_MUCH'));
      await tester.tap(find.text('Join channel'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't join. Try again later."), findsOneWidget);
      expect(closed, isFalse);
      await tester.tap(find.byTooltip('Close'));
      expect(closed, isTrue);
    });
  });

  testWidgets('a notice closes with Done', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(
              showLinkNoticeSheet(context, 'This link has expired.'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('This link has expired.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('This link has expired.'), findsNothing);
  });
}
