import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/chat/upload_overlay.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    double? progress,
    bool failed = false,
    bool canRetry = true,
    VoidCallback? onCancel,
    VoidCallback? onRetry,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildMgTheme(MgColors.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SizedBox(
        width: 200,
        height: 200,
        child: UploadBadge(
          progress: progress,
          failed: failed,
          canRetry: canRetry,
          onCancel: onCancel,
          onRetry: onRetry,
        ),
      ),
    ),
  );

  testWidgets('cancels a running upload', (tester) async {
    var cancelled = 0;
    await show(tester, progress: 0.4, onCancel: () => cancelled++);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.bySemanticsLabel('Cancel sending'));
    expect(cancelled, 1);
  });

  testWidgets('offers retry and delete after a failure', (tester) async {
    var retried = 0;
    var deleted = 0;
    await show(
      tester,
      failed: true,
      onCancel: () => deleted++,
      onRetry: () => retried++,
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.bySemanticsLabel('Try again'));
    await tester.tap(find.bySemanticsLabel('Delete'));
    expect(retried, 1);
    expect(deleted, 1);
    expect(find.bySemanticsLabel('Cancel sending'), findsNothing);
  });

  testWidgets('hides retry when TDLib does not allow it', (tester) async {
    await show(tester, failed: true, canRetry: false);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.bySemanticsLabel('Try again'), findsNothing);
    expect(find.bySemanticsLabel('Delete'), findsOneWidget);
  });

  testWidgets('waits with a turning ring before the upload starts', (
    tester,
  ) async {
    await show(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.bySemanticsLabel('Cancel sending'), findsOneWidget);
    // Settles once it fails, so the spinner does not run forever.
    await show(tester, failed: true);
    await tester.pumpAndSettle();
  });
}
