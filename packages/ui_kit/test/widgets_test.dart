import 'package:flutter/gestures.dart';
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

  testWidgets('avatar shows letters only without a photo or preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const Center(child: MonogramAvatar(name: 'Ada Lovelace', size: 42)),
      ),
    );
    expect(find.text('AL'), findsOneWidget);

    await tester.pumpWidget(
      themed(
        Center(
          child: MonogramAvatar(
            name: 'Ada Lovelace',
            size: 42,
            placeholder: MemoryImage(_pixel),
          ),
        ),
      ),
    );
    expect(find.text('AL'), findsNothing);
    expect(find.byType(ImageFiltered), findsOneWidget);
  });

  testWidgets('a photo decoded now fades in over the preview', (tester) async {
    final opacity = find.byType(AnimatedOpacity);
    // A photo the image cache already holds draws at once, so the one
    // under test must be new to it: fresh bytes, and nothing left over
    // from an earlier test.
    imageCache.clear();
    final photo = MemoryImage(Uint8List.fromList(_pixel));
    // Decoding runs on a real event loop; the first frame has no image
    // yet, so the photo starts transparent rather than popping in.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        themed(
          Center(
            child: MonogramAvatar(
              name: 'Ada',
              size: 42,
              placeholder: MemoryImage(_pixel),
              image: photo,
            ),
          ),
        ),
      );
      expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
    await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
      expect(find.byType(MgSendButton), findsOneWidget);
      expect(find.byTooltip(_labels.record), findsNothing);
    });

    testWidgets('a replacement covers the field and keeps the record button', (
      tester,
    ) async {
      const button = SizedBox(key: ValueKey('rec'), width: 32, height: 32);
      await tester.pumpWidget(
        themed(const Composer(labels: _labels, recordButton: button)),
      );
      expect(find.byKey(const ValueKey('rec')), findsOneWidget);
      final buttonElement = tester.element(find.byKey(const ValueKey('rec')));

      await tester.pumpWidget(
        themed(
          const Composer(
            labels: _labels,
            recordButton: button,
            replacement: Text('0:01', key: ValueKey('bar')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bar')), findsOneWidget);
      // The same element: a press on it keeps going.
      expect(tester.element(find.byKey(const ValueKey('rec'))), buttonElement);
      // The field is still there for when the recording ends, but takes no
      // taps.
      await tester.tap(find.byType(TextField), warnIfMissed: false);
      expect(tester.testTextInput.isVisible, isFalse);
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

  testWidgets('message flash stays still with reduce motion', (tester) async {
    Widget flash(int n) => themed(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MessageFlash(
          flash: n,
          child: const SizedBox(width: 40, height: 20),
        ),
      ),
    );
    Color? color() =>
        (tester
                    .widgetList<DecoratedBox>(
                      find.descendant(
                        of: find.byType(MessageFlash),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .firstOrNull
                    ?.decoration
                as BoxDecoration?)
            ?.color;

    await tester.pumpWidget(flash(0));
    expect(color(), isNull);
    await tester.pumpWidget(flash(1));
    await tester.pump(const Duration(milliseconds: 10));
    final early = color();
    await tester.pump(const Duration(milliseconds: 1200));
    // Full strength the whole time: no fade in or out.
    expect(early, isNotNull);
    expect(color(), early);
    await tester.pump(const Duration(milliseconds: 300));
    expect(color(), isNull);
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
        const FolderSegments(
          selected: 0,
          segments: [
            FolderSegment(label: 'All'),
            FolderSegment(label: 'Work', count: 4),
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
      // The label fades out under the spinner.
      await tester.pump(MgMotion.fast * 2);
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
    Future<void> pump(TextEditingController c) async {
      await tester.pumpWidget(
        themed(Composer(labels: _labels, controller: c, onSend: (_) {})),
      );
      await tester.pumpAndSettle();
    }

    await pump(full);
    expect(find.byType(MgSendButton), findsOneWidget);
    await pump(empty);
    expect(find.byType(MgSendButton), findsNothing);
    empty.text = 'x';
    await tester.pumpAndSettle();
    expect(find.byType(MgSendButton), findsOneWidget);
  });

  testWidgets('composer spans the whole card as its bottom edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themed(
        const Align(
          alignment: Alignment.bottomCenter,
          child: Composer(labels: _labels),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Composer)).width, 1400);
    expect(find.byType(Glass), findsNothing);
  });

  testWidgets('header keeps the title left and the actions at the right '
      'edge', (tester) async {
    tester.view.physicalSize = const Size(1000, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themed(
        const Align(
          alignment: Alignment.topCenter,
          child: ChatHeaderBar(
            title: SizedBox(width: 120, key: Key('title')),
            actions: SizedBox(width: 80),
            fill: SizedBox.expand(key: Key('fill')),
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(ChatHeaderBar));
    final title = tester.getRect(find.byKey(const Key('title')));
    final fill = tester.getRect(find.byKey(const Key('fill')));
    expect(bar.width, 1000);
    // The bar keeps 8 px of air at the left and 6 at the right.
    expect(title.left, 20);
    expect(fill.left, 20);
    expect(fill.right, 1000 - 12 - 80);
  });

  testWidgets('a wide header title stays clear of the actions', (tester) async {
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themed(
        const Align(
          alignment: Alignment.topCenter,
          child: ChatHeaderBar(
            title: SizedBox(width: 300, key: Key('title')),
            actions: SizedBox(width: 80, key: Key('actions')),
          ),
        ),
      ),
    );
    final title = tester.getRect(find.byKey(const Key('title')));
    final actions = tester.getRect(find.byKey(const Key('actions')));
    expect(title.left, 20);
    expect(title.right, lessThanOrEqualTo(actions.left - 8));
  });

  testWidgets('pinned chat tile shows the name and opens the chat', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      themed(
        PinnedChatGrid(
          children: [
            const PinnedChatTile(title: 'Anna Petrova', selected: true),
            PinnedChatTile(title: 'Design', unread: 4, onTap: () => taps++),
          ],
        ),
      ),
    );
    expect(find.text('Anna Petrova'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.text('Design'));
    expect(taps, 1);
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

  testWidgets('a forward\'s source name is a link with a hover underline', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      themed(
        ForwardedBlock(
          source: 'Dodo Pizza',
          date: '12.10.26',
          onSourceTap: () => opened++,
          child: const Text('New secret'),
        ),
      ),
    );
    TextDecoration? decoration() =>
        tester.widget<Text>(find.text('Dodo Pizza')).style?.decoration;
    expect(decoration(), TextDecoration.none);
    expect(find.text('12.10.26'), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Dodo Pizza')));
    await tester.pump();
    expect(decoration(), TextDecoration.underline);
    await mouse.moveTo(tester.getCenter(find.text('New secret')));
    await tester.pump();
    expect(decoration(), TextDecoration.none);

    await tester.tap(find.text('Dodo Pizza'));
    expect(opened, 1);
    // The date beside it is not part of the link.
    await tester.tap(find.text('12.10.26'));
    expect(opened, 1);
  });
}

/// A 1x1 gray PNG.
final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x68, 0x68, 0x68, 0xF8, //
  0x0F, 0x00, 0x05, 0x84, 0x02, 0x80, 0x8C, 0xCD, 0x66, 0x26, 0x00, 0x00, //
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
]);
