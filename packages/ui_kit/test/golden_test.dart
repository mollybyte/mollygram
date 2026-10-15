@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';

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
          const Positioned.fill(child: Wallpaper()),
          Positioned(
            left: SidebarIsland.width + 16,
            right: 0,
            top: 0,
            bottom: 0,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 72, 24, 88),
                    children: const [
                      DatePill('Today'),
                      _Row(
                        out: false,
                        child: TextMessageBubble(
                          text: 'Did the new build land on your Mac?',
                          time: '21:04',
                          outgoing: false,
                        ),
                      ),
                      _Row(
                        out: true,
                        child: TextMessageBubble(
                          text: 'Yes, it opens instantly now',
                          time: '21:10',
                          outgoing: true,
                          status: MessageStatus.read,
                        ),
                      ),
                      _Row(
                        out: true,
                        child: TextMessageBubble(
                          text: 'wrong chat',
                          time: '21:11',
                          outgoing: true,
                          status: MessageStatus.sent,
                          label: 'deleted',
                          dimmed: true,
                        ),
                      ),
                      _Row(
                        out: false,
                        child: TextMessageBubble(
                          text:
                              'A longer message that wraps onto a second line '
                              'so the time has to sit next to its last word.',
                          time: '21:12',
                          outgoing: false,
                          label: 'edited',
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 14,
                  right: 14,
                  child: ChatHeaderBar(
                    title: const ChatTitleCapsule(
                      title: 'Anna Petrova',
                      subtitle: 'online',
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
                  left: 24,
                  right: 24,
                  bottom: 12,
                  child: Composer(labels: _labels),
                ),
              ],
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            bottom: 8,
            width: SidebarIsland.width,
            child: SidebarIsland(
              actions: [
                MgIconButton(
                  icon: MgIcons.compose,
                  tooltip: 'New message',
                  onPressed: () {},
                ),
              ],
              search: const MgSearchField(hintText: 'Search'),
              folders: const FolderTabBar(
                children: [
                  FolderTab(label: 'All', selected: true),
                  FolderTab(label: 'Personal', count: 2),
                  FolderTab(label: 'Work', count: 3),
                  FolderTab(label: 'Channels'),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                children: const [
                  ChatListTile(
                    title: 'Anna Petrova',
                    subtitle: 'Yes, it opens instantly now',
                    time: '21:10',
                    selected: true,
                    unread: 1,
                  ),
                  ChatListTile(
                    title: 'Design',
                    subtitle: 'Mark: pushed the new icons',
                    time: '20:41',
                    unread: 12,
                  ),
                  ChatListTile(
                    title: 'Flutter Desktop',
                    subtitle: 'Release notes are out',
                    time: '18:02',
                    unread: 1234,
                    unreadLabel: '1.2K',
                    muted: true,
                  ),
                  ChatListTile(title: 'Ilya', subtitle: 'ok', time: 'Mon'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.out, required this.child});

  final bool out;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 4),
    child: Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
    ),
  );
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
        size: const Size(380, 200),
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
      await expectLater(
        find.byType(EmojiPanel),
        matchesGoldenFile('goldens/emoji_panel_$theme.png'),
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
            MgMenuItem(label: 'Reply', onSelected: () {}),
            MgMenuItem(label: 'Edit', onSelected: () {}),
            MgMenuItem(label: 'Copy text', onSelected: () {}),
            MgMenuItem(label: 'Forward', onSelected: () {}),
            MgMenuItem(label: 'Delete', destructive: true, onSelected: () {}),
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
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/message_menu_$theme.png'),
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
