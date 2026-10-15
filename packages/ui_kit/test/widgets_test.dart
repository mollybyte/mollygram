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
    testWidgets('pastes text over the selection when the app passes', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': 'big'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final controller = TextEditingController(text: 'a small cat');
      addTearDown(controller.dispose);
      var asked = 0;
      await tester.pumpWidget(
        themed(
          Composer(
            labels: _labels,
            controller: controller,
            onPaste: () async {
              asked++;
              return false;
            },
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 7,
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(asked, 1);
      expect(controller.text, 'a big cat');
      expect(controller.selection, const TextSelection.collapsed(offset: 5));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

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

  testWidgets('group bubble shows the sender over the text', (tester) async {
    await tester.pumpWidget(
      themed(
        const Center(
          child: TextMessageBubble(
            text: 'hello',
            time: '21:10',
            outgoing: false,
            sender: 'Alina',
          ),
        ),
      ),
    );
    final bubble = tester.getRect(find.byType(MessageBubble));
    final name = tester.getRect(find.text('Alina'));
    final text = tester.getRect(
      find.textContaining('hello', findRichText: true),
    );
    expect(bubble.contains(name.topLeft), isTrue);
    expect(name.bottom, lessThanOrEqualTo(text.top));
  });

  testWidgets('a failed message shows the failed mark in red', (tester) async {
    await tester.pumpWidget(
      themed(
        const Center(
          child: MessageMeta(time: '21:10', status: MessageStatus.failed),
        ),
      ),
    );
    final icon = tester.widget<MgIcon>(find.byType(MgIcon));
    expect(icon.icon, MgIcons.failed);
    expect(icon.color, MessageMeta.failedColor);
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

  group('forms', () {
    testWidgets('primary button ignores taps while loading', (tester) async {
      var taps = 0;
      Future<void> pump({required bool loading}) => tester.pumpWidget(
        themed(
          Center(
            child: MgPrimaryButton(
              label: 'Next',
              loading: loading,
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      await pump(loading: false);
      await tester.tap(find.byType(MgPrimaryButton));
      expect(taps, 1);

      await pump(loading: true);
      expect(find.text('Next'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(MgPrimaryButton));
      expect(taps, 1);
    });

    testWidgets('primary button expands to the full width', (tester) async {
      await tester.pumpWidget(
        themed(
          const Center(
            child: SizedBox(
              width: 300,
              child: MgPrimaryButton(label: 'Next', expand: true),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(MgPrimaryButton)).width, 300);
    });

    testWidgets('text field shows its error and submits', (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        themed(
          Center(
            child: SizedBox(
              width: 300,
              child: MgUnderlineField(
                hintText: 'Phone number',
                errorText: 'Invalid number',
                onSubmitted: submitted.add,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Invalid number'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '+1 555');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, ['+1 555']);
    });

    testWidgets('text button reports taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        themed(
          Center(
            child: MgTextButton(
              label: 'Use a QR code',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Use a QR code'));
      expect(taps, 1);
    });
  });

  testWidgets('composer without onSend does not take Enter or send', (
    tester,
  ) async {
    await tester.pumpWidget(themed(const Composer(labels: _labels)));
    await tester.enterText(find.byType(TextField), 'draft');
    await tester.pump();
    final send = tester.widget<MgSendButton>(find.byType(MgSendButton));
    expect(send.onPressed, isNull);
  });

  testWidgets('composer re-syncs the draft state for a new controller', (
    tester,
  ) async {
    final full = TextEditingController(text: 'draft');
    final empty = TextEditingController();
    addTearDown(full.dispose);
    addTearDown(empty.dispose);
    Future<void> pump(TextEditingController c) => tester.pumpWidget(
      themed(Composer(labels: _labels, controller: c, onSend: (_) {})),
    );
    await pump(full);
    expect(find.byType(MgSendButton), findsOneWidget);
    await pump(empty);
    expect(find.byType(MgSendButton), findsNothing);
    empty.text = 'x';
    await tester.pump();
    expect(find.byType(MgSendButton), findsOneWidget);
  });

  testWidgets('composer stays within its max width', (tester) async {
    tester.view.physicalSize = const Size(1400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themed(const SizedBox.expand(child: Composer(labels: _labels))),
    );
    expect(tester.getSize(find.byType(Glass)).width, Composer.maxWidth);
  });

  testWidgets('header keeps the actions at the right edge', (tester) async {
    tester.view.physicalSize = const Size(1000, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themed(
        const Align(
          alignment: Alignment.topCenter,
          child: ChatHeaderBar(
            title: SizedBox(width: 120),
            actions: SizedBox(width: 80),
            fill: SizedBox.expand(key: Key('fill')),
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(ChatHeaderBar));
    final fill = tester.getRect(find.byKey(const Key('fill')));
    expect(bar.width, 1000);
    expect(fill.left, 120);
    expect(fill.right, 1000 - 80);
  });

  testWidgets('form buttons expose a semantic tap', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      themed(
        Column(
          children: [
            MgPrimaryButton(label: 'Next', onPressed: () => taps++),
            MgTextButton(label: 'Use a QR code', onPressed: () => taps++),
          ],
        ),
      ),
    );
    for (final label in ['Next', 'Use a QR code']) {
      tester.semantics.tap(find.semantics.byLabel(label));
    }
    expect(taps, 2);
    semantics.dispose();
  });

  group('sign-in', () {
    testWidgets('underline field turns accent with focus', (tester) async {
      await tester.pumpWidget(
        themed(
          const Center(
            child: SizedBox(
              width: 300,
              child: MgUnderlineField(hintText: 'Code'),
            ),
          ),
        ),
      );
      BorderSide line() =>
          (tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: find.byType(MgUnderlineField),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration!
                  as BoxDecoration)
              .border!
              .bottom;
      expect(line().width, 1);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(line().color, MgColors.light.accent);
      expect(line().width, 2);
    });

    testWidgets('phone field reports country taps and keeps input', (
      tester,
    ) async {
      final code = TextEditingController(text: '+7');
      final number = TextEditingController();
      addTearDown(code.dispose);
      addTearDown(number.dispose);
      var taps = 0;
      await tester.pumpWidget(
        themed(
          SignInPage(
            child: PhoneNumberField(
              country: 'Russian Federation',
              onCountryTap: () => taps++,
              codeController: code,
              numberController: number,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Russian Federation'));
      expect(taps, 1);
      await tester.enterText(find.byType(TextField).last, '9001234567');
      expect(number.text, '9001234567');
      expect(code.text, '+7');
    });

    testWidgets('sign-in page shows back only when asked', (tester) async {
      var back = 0;
      await tester.pumpWidget(themed(const SignInPage(child: SizedBox())));
      expect(find.byType(MgIconButton), findsNothing);
      await tester.pumpWidget(
        themed(
          SignInPage(
            onBack: () => back++,
            backTooltip: 'Back',
            child: const SizedBox(),
          ),
        ),
      );
      await tester.tap(find.byType(MgIconButton));
      expect(back, 1);
    });
  });

  group('EmojiTab', () {
    const labels = EmojiTabLabels(
      search: 'Search emoji',
      recent: 'Recently used',
      noResults: 'No emoji found',
      groups: {EmojiGroup.smileys: 'Smileys', EmojiGroup.flags: 'Flags'},
    );

    Widget tab({
      List<String> recent = const [],
      ValueChanged<String>? onPick,
      Future<List<String>> Function(String)? search,
    }) => themed(
      Center(
        child: EmojiPanel(
          tabs: const ['Emoji'],
          children: [
            EmojiTab(
              labels: labels,
              recent: recent,
              search: search,
              onPick: onPick ?? (_) {},
            ),
          ],
        ),
      ),
    );

    testWidgets('shows recent emoji first and picks one', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(tab(recent: const ['🦊'], onPick: picked.add));
      await tester.pumpAndSettle();

      expect(find.text('Recently used'), findsOneWidget);
      await tester.tap(find.text('🦊'));
      await tester.tap(find.text('😀'));
      expect(picked, ['🦊', '😀']);
    });

    testWidgets('jumps to a group from the bar', (tester) async {
      await tester.pumpWidget(tab());
      await tester.pumpAndSettle();
      expect(find.text('Flags'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Flags'));
      await tester.pump();
      expect(find.text('Flags'), findsOneWidget);
      expect(find.text('😀'), findsNothing);
    });

    testWidgets('searches names and then Telegram keywords', (tester) async {
      final asked = <String>[];
      await tester.pumpWidget(
        tab(
          search: (query) async {
            asked.add(query);
            return ['🐈'];
          },
        ),
      );

      await tester.enterText(find.byType(TextField), 'cat face');
      await tester.pump();
      expect(asked, ['cat face']);
      expect(find.text('🐈'), findsOneWidget);
      expect(find.text('🐱'), findsOneWidget);
      // Keyword matches come first.
      expect(
        tester.getTopLeft(find.text('🐈')).dx,
        lessThan(tester.getTopLeft(find.text('🐱')).dx),
      );

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.text('🐈'), findsOneWidget);
    });

    test('matches every word of the query in the English names', () {
      expect(EmojiTab.matchNames('grinning face'), contains('😀'));
      expect(EmojiTab.matchNames('flag ukraine'), ['🇺🇦']);
      expect(EmojiTab.matchNames('  '), isEmpty);
    });
  });

  testWidgets('shows views and the comments row of a channel post', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      themed(
        Column(
          children: [
            const MessageMeta(time: '17:37', views: '1.2K'),
            CommentsRow(label: '4 comments', onTap: () => opened++),
            const ForwardedBlock(
              source: 'Dodo Pizza',
              date: '12.10.26',
              child: Text('New secret'),
            ),
          ],
        ),
      ),
    );

    expect(find.text('1.2K'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is MgIcon && w.icon == MgIcons.views),
      findsOneWidget,
    );
    await tester.tap(find.text('4 comments'));
    expect(opened, 1);
    expect(find.textContaining('Dodo Pizza'), findsOneWidget);
    expect(find.text('New secret'), findsOneWidget);
  });
}
