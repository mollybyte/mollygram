import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/chat/attachment_preview.dart';
import 'package:mollygram_core/mollygram_core.dart';
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

  Future<void> open(WidgetTester tester, List<String> names) async {
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

  testWidgets('files offer no spoiler', (tester) async {
    await open(tester, ['sea.jpg']);
    await tester.tap(find.text('Send as files'));
    await tester.pump();
    expect(find.text('Hide with a spoiler'), findsNothing);
  });

  testWidgets('cancel sends nothing', (tester) async {
    await open(tester, ['notes.pdf']);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(closed, isTrue);
    expect(choice, isNull);
  });
}
