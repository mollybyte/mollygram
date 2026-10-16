import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/chat/attachment_preview.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  late Directory directory;
  AttachmentChoice? choice;
  var closed = false;

  setUp(() {
    choice = null;
    closed = false;
    directory = Directory.systemTemp.createTempSync('attach');
    for (final name in ['sea.jpg', 'notes.pdf']) {
      File('${directory.path}/$name').writeAsBytesSync([1, 2, 3]);
    }
  });

  tearDown(() => directory.deleteSync(recursive: true));

  Future<void> open(
    WidgetTester tester,
    List<String> names, {
    bool private = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              choice = await showAttachmentPreview(
                context,
                paths: [for (final name in names) '${directory.path}/$name'],
                caption: 'Draft',
                allowSelfDestruct: private,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
  }

  testWidgets('sends photos compressed', (tester) async {
    await open(tester, ['sea.jpg', 'notes.pdf']);
    expect(find.text('Send 2 files'), findsOneWidget);
    expect(find.text('notes.pdf'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.pump();

    expect(closed, isTrue);
    expect(
      [for (final file in choice!.files) file.kind],
      [OutgoingKind.photo, OutgoingKind.document],
    );
    expect(choice!.caption, 'Draft');
  });

  testWidgets('sends without sound or later from the send menu', (
    tester,
  ) async {
    await open(tester, ['notes.pdf']);
    await tester.tap(find.text('Send'), buttons: kSecondaryButton);
    await tester.pump();
    await tester.tap(find.text('Send without sound'));
    await tester.pump();
    expect(closed, isTrue);
    expect(choice!.silent, isTrue);
    expect(choice!.schedule, isNull);

    closed = false;
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.tap(find.text('Send'), buttons: kSecondaryButton);
    await tester.pump();
    await tester.tap(find.text('Schedule message…'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '23:59');
    await tester.pump();
    await tester.tap(find.text('Schedule'));
    await tester.pump();
    expect(closed, isTrue);
    expect(choice!.silent, isFalse);
    final state = choice!.schedule! as td.MessageSchedulingStateSendAtDate;
    final when = DateTime.fromMillisecondsSinceEpoch(state.sendDate * 1000);
    expect(when.hour, 23);
    expect(when.minute, 59);
    expect(when.isAfter(DateTime.now()), isTrue);
  });

  testWidgets('sends photos as files when asked', (tester) async {
    await open(tester, ['sea.jpg']);
    expect(find.text('Send 1 photo'), findsOneWidget);

    await tester.tap(find.text('Send as files'));
    await tester.pump();
    // Listed by name now, like any document.
    expect(find.text('sea.jpg'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'As is');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(choice!.files.single.kind, OutgoingKind.document);
    expect(choice!.caption, 'As is');
  });

  testWidgets('hides photos behind a spoiler when asked', (tester) async {
    await open(tester, ['sea.jpg', 'notes.pdf']);
    await tester.tap(find.text('Hide with a spoiler'));
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();

    expect([for (final file in choice!.files) file.spoiler], [true, false]);
  });

  testWidgets('sends photos one by one when grouping is off', (tester) async {
    File('${directory.path}/b.jpg').writeAsBytesSync([1, 2, 3]);
    await open(tester, ['sea.jpg', 'b.jpg']);
    await tester.tap(find.text('Group as an album'));
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();

    expect([for (final file in choice!.files) file.alone], [true, true]);
  });

  testWidgets('files offer no spoiler', (tester) async {
    await open(tester, ['sea.jpg']);
    await tester.tap(find.text('Send as files'));
    await tester.pump();
    expect(find.text('Hide with a spoiler'), findsNothing);
  });

  testWidgets('sets a self-destruct timer in a private chat', (tester) async {
    await open(tester, ['sea.jpg']);
    expect(find.text('Self-destruct timer'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    await open(tester, ['sea.jpg', 'notes.pdf'], private: true);
    await tester.tap(find.text('Off'));
    await tester.pump();
    await tester.tap(find.text('10 seconds'));
    await tester.pump();
    expect(find.text('10 seconds'), findsOneWidget);
    await tester.tap(find.text('Send'));
    await tester.pump();

    expect([for (final file in choice!.files) file.selfDestruct], [10, 0]);
  });

  testWidgets('cancel sends nothing', (tester) async {
    await open(tester, ['notes.pdf']);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(closed, isTrue);
    expect(choice, isNull);
  });
}
