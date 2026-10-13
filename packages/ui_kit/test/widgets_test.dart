import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'harness.dart';

const _labels = ComposerLabels(
  hint: 'Message',
  attach: 'Attach',
  emoji: 'Emoji and stickers',
  record: 'Record a voice or video message',
  send: 'Send',
);

void main() {
  testWidgets('every icon renders', (tester) async {
    await tester.pumpWidget(
      themed(Wrap(children: [for (final icon in MgIcons.all) MgIcon(icon)])),
    );
    expect(find.byType(MgIcon), findsNWidgets(MgIcons.all.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon names are unique', (tester) async {
    final names = MgIcons.all.map((i) => i.name).toSet();
    expect(names.length, MgIcons.all.length);
  });

  testWidgets('icon button taps and exposes its label', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      themed(
        Center(
          child: MgIconButton(
            icon: MgIcons.ghost,
            tooltip: 'Ghost mode',
            selected: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MgIconButton));
    expect(taps, 1);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Ghost mode')),
      isSemantics(
        label: 'Ghost mode',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasToggledState: true,
        isToggled: true,
      ),
    );
    final icon = tester.widget<MgIcon>(find.byType(MgIcon));
    expect(icon.color, MgColors.light.accent);
    semantics.dispose();
  });

  group('Composer', () {
    testWidgets('shows the microphone until there is a draft', (tester) async {
      await tester.pumpWidget(themed(const Composer(labels: _labels)));
      expect(find.byType(MgSendButton), findsNothing);
      expect(find.byTooltip(_labels.record), findsOneWidget);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(find.byType(MgSendButton), findsNothing);

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();
      expect(find.byType(MgSendButton), findsOneWidget);
      expect(find.byTooltip(_labels.record), findsNothing);
    });

    testWidgets('sends on the button and on Enter, not on Shift+Enter', (
      tester,
    ) async {
      final sent = <String>[];
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        themed(
          Composer(labels: _labels, controller: controller, onSend: sent.add),
        ),
      );
      await tester.enterText(find.byType(TextField), 'first');
      await tester.pump();
      await tester.tap(find.byType(MgSendButton));
      expect(sent, ['first']);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sent, ['first', 'first']);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(sent, ['first', 'first']);

      controller.clear();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sent, ['first', 'first']);
      expect(find.byType(MgSendButton), findsNothing);
    });
  });

  testWidgets('chat list tile shows unread and reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      themed(
        SizedBox(
          width: 300,
          child: ChatListTile(
            title: 'Anna Petrova',
            subtitle: 'see you tomorrow',
            time: '21:10',
            unread: 3,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('AP'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byType(ChatListTile));
    expect(taps, 1);
  });

  testWidgets('folder tab hides a zero counter', (tester) async {
    await tester.pumpWidget(
      themed(
        const FolderTabBar(
          children: [
            FolderTab(label: 'All', selected: true),
            FolderTab(label: 'Work', count: 4),
          ],
        ),
      ),
    );
    expect(find.text('All'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('text bubble leaves room for the meta', (tester) async {
    await tester.pumpWidget(
      themed(
        const Center(
          child: TextMessageBubble(
            text: 'ok',
            time: '21:10',
            outgoing: true,
            status: MessageStatus.read,
            label: 'edited',
          ),
        ),
      ),
    );
    final bubble = tester.getRect(find.byType(MessageBubble));
    final meta = tester.getRect(find.byType(MessageMeta));
    expect(bubble.contains(meta.topLeft), isTrue);
    expect(bubble.contains(meta.bottomRight - const Offset(1, 1)), isTrue);
    final text = tester.getRect(find.textContaining('ok', findRichText: true));
    expect(text.right, greaterThanOrEqualTo(meta.right - 1));
  });

  testWidgets('glass turns blur off inside a scope without blur', (
    tester,
  ) async {
    Future<BackdropFilter> pump({required bool blur}) async {
      await tester.pumpWidget(
        themed(
          GlassScope(
            blur: blur,
            child: const Center(
              child: Glass(radius: 22, child: SizedBox(width: 80, height: 40)),
            ),
          ),
        ),
      );
      return tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    }

    expect((await pump(blur: true)).enabled, isTrue);
    expect((await pump(blur: false)).enabled, isFalse);
  });

  testWidgets('MgColors.of falls back to light without the extension', (
    tester,
  ) async {
    late MgColors colors;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            colors = MgColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(colors, same(MgColors.light));
  });
}
