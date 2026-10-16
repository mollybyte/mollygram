import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'harness.dart';

void main() {
  testWidgets('menu moves with the arrow keys and picks with Enter', (
    tester,
  ) async {
    final picked = <String>[];
    await tester.pumpWidget(
      themed(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showMgMenu(
              context,
              position: const Offset(20, 20),
              items: [
                MgMenuItem(label: 'Reply', onSelected: () => picked.add('r')),
                const MgMenuItem.divider(),
                MgMenuItem(
                  label: 'Mute',
                  submenu: [
                    MgMenuItem(
                      label: '1 hour',
                      onSelected: () => picked.add('1h'),
                    ),
                    MgMenuItem(
                      label: 'Forever',
                      onSelected: () => picked.add('f'),
                    ),
                  ],
                ),
                MgMenuItem(label: 'Delete', onSelected: () => picked.add('d')),
              ],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Down from nothing lands on the first row; the divider is skipped.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Forever'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked, ['f']);
    expect(find.text('Reply'), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Up from nothing lands on the last row.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked, ['f', 'd']);
  });
}
