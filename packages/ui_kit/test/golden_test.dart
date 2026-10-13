@Tags(['golden'])
library;

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

    testWidgets('sign-in card $theme', skip: _skip, (tester) async {
      await _shoot(
        tester,
        GlassScope(
          child: Stack(
            children: [
              const Positioned.fill(child: Wallpaper()),
              Center(
                child: GlassCard(
                  width: 340,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Your phone number',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const MgTextField(hintText: 'Phone number'),
                      const SizedBox(height: 10),
                      const MgTextField(
                        hintText: 'Code',
                        errorText: 'Invalid code',
                      ),
                      const SizedBox(height: 16),
                      MgPrimaryButton(
                        label: 'Next',
                        expand: true,
                        onPressed: () {},
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: MgTextButton(
                          label: 'Use a QR code',
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        colors,
        'sign_in_card_$theme',
        size: const Size(520, 420),
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
        size: const Size(380, 120),
      );
    });
  }
}
