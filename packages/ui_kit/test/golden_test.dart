@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'harness.dart';

// Golden images are rendered on Linux, as in CI; other hosts rasterize text
// slightly differently. Update with `flutter test --update-goldens` on Linux.
final _skip = !Platform.isLinux;

const _labels = ComposerLabels(
  hint: 'Message',
  attach: 'Attach',
  emoji: 'Emoji and stickers',
  record: 'Record a voice or video message',
  send: 'Send',
);

/// The main window from design/Main.dc.html, built from the kit.
class _Window extends StatelessWidget {
  const _Window({this.blur = true});

  final bool blur;

  @override
  Widget build(BuildContext context) {
    return GlassScope(
      blur: blur,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: MgColors.of(context).frame)),
          Positioned(
            left: SidebarIsland.width,
            right: SidebarIsland.topInset,
            top: SidebarIsland.topInset,
            bottom: SidebarIsland.topInset,
            child: ChatCard(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(28, 70, 28, 64),
                      children: const [
                        DatePill('Today'),
                        _Flat(
                          name: 'Anna Petrova',
                          time: '21:04',
                          lines: ['Did the new build land on your Mac?'],
                        ),
                        _Flat(
                          name: 'You',
                          time: '21:10',
                          lines: [
                            'Yes, it opens instantly now',
                            'and the list keeps up while it scrolls',
                          ],
                        ),
                        _Flat(
                          name: 'Anna Petrova',
                          time: '21:12',
                          lines: [
                            'A longer message that wraps onto a second line '
                                'so the reader sees how text flows in the card.',
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ChatHeaderBar(
                      title: const ChatTitleCapsule(
                        title: 'Anna Petrova',
                        subtitle: 'online',
                        subtitleAccent: true,
                      ),
                      actions: ChatActionsCapsule(
                        children: [
                          MgIconButton(
                            icon: MgIcons.search,
                            tooltip: 'Search in chat',
                            onPressed: () {},
                          ),
                          MgIconButton(
                            icon: MgIcons.call,
                            tooltip: 'Call',
                            onPressed: () {},
                          ),
                          MgIconButton(
                            icon: MgIcons.ghost,
                            tooltip: 'Ghost mode',
                            selected: true,
                            onPressed: () {},
                          ),
                          MgIconButton(
                            icon: MgIcons.panel,
                            tooltip: 'Chat info',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Composer(labels: _labels),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: SidebarIsland.width,
            child: SidebarIsland(
              folders: const FolderSegments(
                selected: 0,
                segments: [
                  FolderSegment(label: 'All', icon: MgIcons.list),
                  FolderSegment(
                    label: 'Personal',
                    icon: MgIcons.profile,
                    count: 2,
                  ),
                  FolderSegment(label: 'Work', icon: MgIcons.group, count: 3),
                  FolderSegment(label: 'Channels', icon: MgIcons.channel),
                ],
              ),
              actions: [
                MgIconButton(
                  icon: MgIcons.compose,
                  tooltip: 'New message',
                  onPressed: () {},
                ),
              ],
              search: const MgSearchField(hintText: 'Search'),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                children: const [
                  ChatListTile(
                    title: 'Anna Petrova',
                    sender: 'You',
                    subtitle:
                        'yes, it opens instantly now, and the '
                        'list keeps up while it scrolls',
                    time: '21:10',
                    status: MessageStatus.read,
                    selected: true,
                    online: true,
                    pinned: true,
                  ),
                  ChatListTile(
                    title: 'Design',
                    subtitle: 'pushed the new icons',
                    kind: ChatRowKind.group,
                    sender: 'Mark',
                    senderAvatar: MonogramAvatar(name: 'Mark', size: 15),
                    time: '20:41',
                    unread: 12,
                    mentions: true,
                    pinned: true,
                  ),
                  ChatListTile(
                    title: 'Mark',
                    subtitle: '',
                    activity: 'typing',
                    time: '20:30',
                    online: true,
                    reactions: true,
                  ),
                  ChatListTile(
                    title: 'Flutter Desktop',
                    kind: ChatRowKind.channel,
                    subtitle:
                        'Release notes are out: what is new in the desktop '
                        'embedder this month',
                    verified: true,
                    time: '18:02',
                    unread: 1234,
                    unreadLabel: '1.2K',
                    muted: true,
                  ),
                  ChatListTile(
                    title: 'Vera',
                    subtitle: 'Photo',
                    time: 'Tue',
                    secret: true,
                    markedUnread: true,
                  ),
                  ChatListTile(
                    title: 'Ilya',
                    subtitle: 'ok',
                    time: 'Mon',
                    status: MessageStatus.sent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A flat message run as the app's timeline draws it.
class _Flat extends StatelessWidget {
  const _Flat({required this.name, required this.time, required this.lines});

  final String name;
  final String time;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonogramAvatar(name: name, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: mgTextStyle(c, weight: FontWeight.w600, height: 1.35),
                ),
                for (final line in lines)
                  Text(
                    line,
                    style: mgTextStyle(c, size: MgType.message, height: 1.35),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(time, style: MessageMeta.styleOf(c)),
          ),
        ],
      ),
    );
  }
}

Future<void> _shoot(
  WidgetTester tester,
  Widget child,
  MgColors colors,
  String name, {
  Size size = const Size(1100, 640),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themed(child, colors: colors));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  for (final (colors, theme) in [
    (MgColors.light, 'light'),
    (MgColors.dark, 'dark'),
  ]) {
    testWidgets('window $theme', skip: _skip, (tester) async {
      await _shoot(tester, const _Window(), colors, 'window_$theme');
    });

    testWidgets('window $theme without blur', skip: _skip, (tester) async {
      await _shoot(
        tester,
        const _Window(blur: false),
        colors,
        'window_${theme}_solid',
      );
    });

    testWidgets('sign-in QR $theme', skip: _skip, (tester) async {
      await _shoot(
        tester,
        SignInPage(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SignInHeader(
                leading: QrFrame(qr: _FakeQr()),
                title: 'Log in to Mollygram by QR code',
              ),
              const SizedBox(height: 24),
              const SignInSteps(
                steps: [
                  'Open Telegram on your phone',
                  'Go to Settings > Devices > Link Desktop Device',
                  'Point your phone at this screen to confirm login',
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: MgTextButton(
                  label: 'Log in by phone number',
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        colors,
        'sign_in_qr_$theme',
        size: const Size(760, 640),
      );
    });

    testWidgets('sign-in phone $theme', skip: _skip, (tester) async {
      final code = TextEditingController(text: '+7');
      final number = TextEditingController();
      addTearDown(code.dispose);
      addTearDown(number.dispose);
      await _shoot(
        tester,
        SignInPage(
          onBack: () {},
          backTooltip: 'Back',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SignInHeader(
                title: 'Your phone number',
                subtitle:
                    'Please confirm your country code and enter your '
                    'phone number.',
              ),
              const SizedBox(height: 28),
              PhoneNumberField(
                country: 'Russian Federation',
                onCountryTap: () {},
                codeController: code,
                numberController: number,
                numberHint: '900 123 45 67',
                autofocus: false,
              ),
              const SizedBox(height: 32),
              MgPrimaryButton(
                label: 'Next',
                expand: true,
                height: 42,
                onPressed: () {},
              ),
            ],
          ),
        ),
        colors,
        'sign_in_phone_$theme',
        size: const Size(760, 640),
      );
    });

    testWidgets('sign-in code $theme', skip: _skip, (tester) async {
      await _shoot(
        tester,
        SignInPage(
          onBack: () {},
          backTooltip: 'Back',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SignInHeader(
                title: '+7 900 123 45 67',
                subtitle:
                    'We have sent the code to the Telegram app on your '
                    'other device.',
              ),
              const SizedBox(height: 28),
              const MgUnderlineField(
                hintText: 'Code',
                errorText: 'Invalid code',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              MgPrimaryButton(
                label: 'Next',
                expand: true,
                height: 42,
                onPressed: () {},
              ),
            ],
          ),
        ),
        colors,
        'sign_in_code_$theme',
        size: const Size(760, 640),
      );
    });

    testWidgets('icons $theme', skip: _skip, (tester) async {
      await _shoot(
        tester,
        Builder(
          builder: (context) => ColoredBox(
            color: MgColors.of(context).bubbleIn,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final icon in MgIcons.all)
                    MgIcon(icon, size: 24, color: MgColors.of(context).fg),
                ],
              ),
            ),
          ),
        ),
        colors,
        'icons_$theme',
        size: const Size(380, 236),
      );
    });

    testWidgets('emoji panel $theme', skip: _skip, (tester) async {
      tester.view.physicalSize = const Size(480, 460);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themed(
          Stack(
            children: [
              const Positioned.fill(child: Wallpaper()),
              Positioned(
                right: 24,
                bottom: 24,
                child: EmojiPanel(
                  tabs: const ['Emoji', 'Stickers'],
                  children: [
                    EmojiTab(
                      labels: const EmojiTabLabels(
                        search: 'Search emoji',
                        recent: 'Recently used',
                        noResults: 'No emoji found',
                        groups: {EmojiGroup.smileys: 'Smileys'},
                      ),
                      recent: const ['a', 'b', 'c'],
                      onPick: (_) {},
                    ),
                    const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
          colors: colors,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(EmojiPanel),
        matchesGoldenFile('goldens/emoji_panel_$theme.png'),
      );
    });

    testWidgets('pinned bar $theme', skip: _skip, (tester) async {
      tester.view.physicalSize = const Size(520, 160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themed(
          Stack(
            children: [
              const Positioned.fill(child: Wallpaper()),
              Positioned(
                left: 14,
                right: 14,
                top: 20,
                child: PinnedBar(
                  title: 'Pinned message #2',
                  text: 'Release notes for 0.1.0 are in the channel',
                  index: 1,
                  count: 3,
                  onTap: () {},
                  closeTooltip: 'Hide pinned messages',
                  onClose: () {},
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                top: 80,
                child: PinnedBar(
                  title: 'Pinned message',
                  text: 'Photo',
                  index: 0,
                  count: 1,
                  thumbnail: const ColoredBox(color: Color(0xFF6BA587)),
                  onTap: () {},
                  closeTooltip: 'Hide pinned messages',
                  onClose: () {},
                ),
              ),
            ],
          ),
          colors: colors,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Stack).first,
        matchesGoldenFile('goldens/pinned_bar_$theme.png'),
      );
    });

    testWidgets('calendar $theme', skip: _skip, (tester) async {
      tester.view.physicalSize = const Size(320, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themed(
          Stack(
            children: [
              const Positioned.fill(child: Wallpaper()),
              Positioned(
                left: 24,
                top: 20,
                child: MgCalendar(
                  month: DateTime(2026, 10),
                  today: DateTime(2026, 10, 15),
                  first: DateTime(2026, 10, 3),
                  onPick: (_) {},
                  monthTitle: (_) => 'October 2026',
                  weekdays: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
                  previousTooltip: 'Previous month',
                  nextTooltip: 'Next month',
                ),
              ),
            ],
          ),
          colors: colors,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Stack).first,
        matchesGoldenFile('goldens/calendar_$theme.png'),
      );
    });

    testWidgets('selection bar $theme', skip: _skip, (tester) async {
      tester.view.physicalSize = const Size(640, 140);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themed(
          Stack(
            children: [
              const Positioned.fill(child: Wallpaper()),
              Positioned(
                left: 24,
                right: 24,
                top: 20,
                child: SelectionBar(
                  countLabel: '3 selected',
                  closeTooltip: 'Clear selection',
                  onClose: () {},
                  actions: [
                    SelectionBarAction(label: 'Copy', onPressed: () {}),
                    const SelectionBarAction(label: 'Forward', onPressed: null),
                    SelectionBarAction(
                      label: 'Delete',
                      destructive: true,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              const Positioned(
                left: 24,
                top: 84,
                child: Row(
                  spacing: 12,
                  children: [
                    SelectCheck(selected: false),
                    SelectCheck(selected: true),
                  ],
                ),
              ),
            ],
          ),
          colors: colors,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Stack).first,
        matchesGoldenFile('goldens/selection_bar_$theme.png'),
      );
    });

    testWidgets('selection menu $theme', skip: _skip, (tester) async {
      tester.view.physicalSize = const Size(420, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget letter(BuildContext context, String v, Color c) =>
          selectionLetter(context, v, c, weight: FontWeight.w800);
      await tester.pumpWidget(
        themed(
          Stack(
            children: [
              const Positioned.fill(child: Wallpaper()),
              Builder(
                builder: (context) => SelectionMenu(
                  anchors: const TextSelectionToolbarAnchors(
                    primaryAnchor: Offset(80, 40),
                    secondaryAnchor: Offset(80, 60),
                  ),
                  formats: [
                    SelectionFormatButton(
                      glyph: (c) => letter(context, 'B', c),
                      tooltip: 'Bold',
                      active: true,
                      onPressed: () {},
                    ),
                    for (final icon in [
                      MgIcons.quote,
                      MgIcons.link,
                      MgIcons.edit,
                      MgIcons.copy,
                      MgIcons.reply,
                      MgIcons.select,
                      MgIcons.forward,
                    ])
                      SelectionFormatButton(
                        glyph: (c) => selectionIcon(icon, c),
                        tooltip: 'Format',
                        active: false,
                        onPressed: () {},
                      ),
                  ],
                  commands: [
                    SelectionCommand(
                      label: 'Cut',
                      shortcut: '\u2318X',
                      onPressed: () {},
                    ),
                    SelectionCommand(
                      label: 'Copy',
                      shortcut: '\u2318C',
                      onPressed: () {},
                    ),
                    SelectionCommand(
                      label: 'Paste',
                      shortcut: '\u2318V',
                      onPressed: () {},
                    ),
                    SelectionCommand(
                      label: 'Select all',
                      shortcut: '\u2318A',
                      onPressed: () {},
                    ),
                  ],
                  extra: [
                    SelectionCommand(label: 'Plain text', onPressed: () {}),
                  ],
                ),
              ),
            ],
          ),
          colors: colors,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/selection_menu_$theme.png'),
      );
    });

    testWidgets('message menu $theme', skip: _skip, (tester) async {
      tester.view.physicalSize = const Size(640, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themed(
          Stack(
            children: [
              const Positioned.fill(child: Wallpaper()),
              Positioned(
                left: 24,
                right: 24,
                bottom: 12,
                child: Composer(
                  labels: _labels,
                  header: ComposerContextBar(
                    title: 'Alina',
                    text: 'Did the new build land on your Mac?',
                    closeTooltip: 'Close',
                    onClose: () {},
                  ),
                ),
              ),
            ],
          ),
          colors: colors,
        ),
      );
      final context = tester.element(find.byType(Composer));
      unawaited(
        showMgMenu(
          context,
          position: const Offset(60, 30),
          header: ReactionBar(
            reactions: const ['a', 'b', 'c', 'd', 'e', 'f'],
            chosen: const {'b'},
            onPick: (_) {},
          ),
          items: [
            MgMenuItem(label: 'Reply', icon: MgIcons.reply, onSelected: () {}),
            MgMenuItem(label: 'Edit', icon: MgIcons.edit, onSelected: () {}),
            MgMenuItem(
              label: 'Copy text',
              icon: MgIcons.copy,
              onSelected: () {},
            ),
            MgMenuItem(
              label: 'Forward',
              icon: MgIcons.forward,
              onSelected: () {},
            ),
            MgMenuItem(
              label: 'Delete',
              icon: MgIcons.trash,
              destructive: true,
              onSelected: () {},
            ),
          ],
        ),
      );
      await tester.pump();
      unawaited(
        showMgConfirm(
          context,
          title: 'Delete message?',
          confirmLabel: 'Delete',
          cancelLabel: 'Cancel',
          option: 'Also delete for Alina',
          optionValue: true,
          destructive: true,
        ),
      );
      await tester.pump();
      // The alert fades and grows in.
      await tester.pump(MgMotion.standard);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/message_menu_$theme.png'),
      );
    });

    testWidgets('context menu $theme', skip: _skip, (tester) async {
      tester.view.physicalSize = const Size(440, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themed(const Wallpaper(), colors: colors));
      final context = tester.element(find.byType(Wallpaper));
      MgMenuItem row(String label, MgIconData icon) =>
          MgMenuItem(label: label, icon: icon, onSelected: () {});
      unawaited(
        showMgMenu(
          context,
          position: const Offset(100, 40),
          header: ReactionBar(
            reactions: const ['a', 'b', 'c', 'd', 'e', 'f'],
            onPick: (_) {},
            onMore: () {},
          ),
          items: [
            row('Reply', MgIcons.reply),
            row('Copy text', MgIcons.copy),
            row('Copy link', MgIcons.link),
            const MgMenuItem.divider(),
            row('Forward', MgIcons.forward),
            row('Pin', MgIcons.pinOutline),
            row('Select', MgIcons.select),
            const MgMenuItem.divider(),
            row('Edit', MgIcons.edit),
            MgMenuItem(
              label: 'Delete',
              icon: MgIcons.trash,
              destructive: true,
              onSelected: () {},
            ),
          ],
        ),
      );
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Forward')));
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/context_menu_$theme.png'),
      );
    });

    testWidgets('dropdown $theme', skip: _skip, (tester) async {
      tester.view.physicalSize = const Size(420, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themed(
          const Stack(
            children: [
              Positioned.fill(child: Wallpaper()),
              Positioned(
                right: 16,
                top: 16,
                child: SizedBox(width: 28, height: 28),
              ),
            ],
          ),
          colors: colors,
        ),
      );
      final context = tester.element(find.byType(Wallpaper));
      unawaited(
        showMgDropdown(
          context,
          anchor: const Rect.fromLTWH(376, 16, 28, 28),
          items: [
            MgMenuItem(
              label: 'View info',
              icon: MgIcons.profile,
              onSelected: () {},
            ),
            MgMenuItem(
              label: 'Search',
              icon: MgIcons.search,
              onSelected: () {},
            ),
            MgMenuItem(
              label: 'Mute',
              icon: MgIcons.muted,
              submenu: [MgMenuItem(label: '1 hour', onSelected: () {})],
            ),
            const MgMenuItem.divider(),
            MgMenuItem(
              label: 'Leave group',
              icon: MgIcons.trash,
              destructive: true,
              onSelected: () {},
            ),
          ],
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dropdown_$theme.png'),
      );
    });
  }
}

/// A deterministic stand-in for a QR code.
class _FakeQr extends StatelessWidget {
  const _FakeQr();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _QrPainter());
}

class _QrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const n = 29;
    final cell = size.width / n;
    final paint = Paint()..color = const Color(0xFF000000);
    bool finder(int x, int y) {
      for (final (fx, fy) in [(0, 0), (n - 7, 0), (0, n - 7)]) {
        final dx = x - fx, dy = y - fy;
        if (dx >= 0 && dx < 7 && dy >= 0 && dy < 7) {
          final edge = dx == 0 || dx == 6 || dy == 0 || dy == 6;
          final core = dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4;
          return edge || core;
        }
      }
      return false;
    }

    bool inFinder(int x, int y) =>
        (x < 8 && y < 8) || (x >= n - 8 && y < 8) || (x < 8 && y >= n - 8);
    var seed = 7;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        final on = inFinder(x, y) ? finder(x, y) : seed % 3 == 0;
        if (on) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x * cell, y * cell, cell, cell).deflate(0.4),
              Radius.circular(cell * 0.3),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => false;
}
