import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'harness.dart';

ReactionChip _chip(int count, {bool chosen = false, String emoji = '👍'}) =>
    ReactionChip(emoji: emoji, count: count, chosen: chosen);

Widget _row(List<(String, ReactionChip)> chips, {bool reduced = false}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Align(
        alignment: Alignment.topLeft,
        child: ReactionRow(chips: chips),
      ),
    );

void main() {
  testWidgets('the count rolls to the new number and settles', (tester) async {
    await tester.pumpWidget(themed(_row([('👍', _chip(1))])));
    await tester.pumpWidget(themed(_row([('👍', _chip(2))])));
    await tester.pump(const Duration(milliseconds: 80));
    // Mid-roll both numbers are there.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a reaction added to a shown row pops in, the others stay', (
    tester,
  ) async {
    await tester.pumpWidget(themed(_row([('👍', _chip(1))])));
    await tester.pumpWidget(
      themed(
        _row([('👍', _chip(1)), ('🔥', _chip(1, chosen: true, emoji: '🔥'))]),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    final fire = find.ancestor(
      of: find.text('🔥'),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(fire.first).opacity, lessThan(1));
    final thumb = find.ancestor(
      of: find.text('👍'),
      matching: find.byType(Opacity),
    );
    expect(thumb, findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('with reduced motion nothing animates', (tester) async {
    await tester.pumpWidget(themed(_row([('👍', _chip(1))], reduced: true)));
    await tester.pumpWidget(
      themed(
        _row([('👍', _chip(2)), ('🔥', _chip(1, emoji: '🔥'))], reduced: true),
      ),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('🔥'), matching: find.byType(Opacity)),
      findsNothing,
    );
  });
}
