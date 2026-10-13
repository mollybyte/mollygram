import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

/// Window screenshots for visual review, not golden tests:
/// MG_SHOT_DIR=/path flutter test test/screenshot_test.dart. Skipped when the
/// variable is not set.
void main() {
  final dir = Platform.environment['MG_SHOT_DIR'];

  Future<void> loadFonts() async {
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final path in files) {
        final f = File(path);
        if (f.existsSync()) {
          loader.addFont(
            Future.value(ByteData.sublistView(f.readAsBytesSync())),
          );
        }
      }
      await loader.load();
    }

    await load('Inter', [
      for (final w in ['Regular', 'Medium', 'SemiBold'])
        '/usr/share/fonts/opentype/inter/Inter-$w.otf',
    ]);
    await load('DejaVu', ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']);
  }

  for (final dark in [false, true]) {
    for (final palette in [false, true]) {
      final name =
          'shell_${palette ? 'palette' : 'split'}_'
          '${dark ? 'dark' : 'light'}';
      testWidgets(name, (tester) async {
        tester.view.physicalSize = const Size(2880, 1800);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        // Show the macOS key labels.
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        await tester.runAsync(loadFonts);

        final controller = WorkspaceController()
          ..open(1)
          ..open(2, target: OpenTarget.split)
          ..open(7, target: OpenTarget.newTab)
          ..open(4, target: OpenTarget.newTab)
          ..selectTab(0);
        addTearDown(controller.dispose);
        final shell = GlobalKey<WorkspaceShellState>();
        final colors = dark ? ShellColors.dark : ShellColors.light;

        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('shot'),
            child: WidgetsApp(
              color: colors.accent,
              debugShowCheckedModeBanner: false,
              builder: (context, _) => ShellTheme(
                colors: colors,
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: const ['DejaVu'],
                    fontSize: 13,
                    color: colors.fg,
                  ),
                  child: _Wallpaper(
                    dark: dark,
                    child: WorkspaceShell(
                      key: shell,
                      controller: controller,
                      directory: MockChatDirectory(),
                      strings: ShellStrings.en,
                      sidebarWidth: 320,
                      sidebar: _Sidebar(dark: dark),
                      paneBuilder: (context, chat, focused) => chat == null
                          ? const EmptyPane(strings: ShellStrings.en)
                          : _MockChat(dark: dark, right: chat == 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        if (palette) {
          shell.currentState!.openPalette();
          await tester.pump();
        }
        await tester.pump();
        await tester.runAsync(() async {
          final boundary = tester.renderObject(
            find.byKey(const Key('shot')),
          ) as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
        debugDefaultTargetPlatformOverride = null;
      }, skip: dir == null);
    }
  }
}

/// The Telegram four-point wallpaper, approximated with radial gradients.
class _Wallpaper extends StatelessWidget {
  const _Wallpaper({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = dark
        ? const [0xFF2D4A5C, 0xFF1C3442, 0xFF3B5465, 0xFF203845, 0xFF1A2A35]
        : const [0xFFDBDDBB, 0xFF6BA587, 0xFFD5D88D, 0xFF88B884, 0xFFB5C99E];
    const spots = [
      Alignment(-0.76, -0.64),
      Alignment(0.76, -0.76),
      Alignment(0.64, 0.76),
      Alignment(-0.64, 0.8),
    ];
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color(colors[4])),
        for (var i = 0; i < 4; i++)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: spots[i],
                radius: 0.8,
                colors: [
                  Color(colors[i]),
                  Color(colors[i]).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = ShellTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0x6B1C1E22) : const Color(0x6BFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.rim),
        ),
        padding: const EdgeInsets.fromLTRB(10, 52, 10, 0),
        child: Column(
          children: [
            for (var i = 0; i < 9; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: i == 0 ? c.accent : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const MonogramAvatar(initials: '', size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.4 + (i * 13 % 40) / 100,
                            child: _Bar(height: 9, on: i == 0),
                          ),
                          const SizedBox(height: 6),
                          FractionallySizedBox(
                            widthFactor: 0.8,
                            child: _Bar(height: 8, on: i == 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.on});

  final double height;
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: on ? const Color(0x99FFFFFF) : ShellTheme.of(context).field,
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

/// Placeholder bubbles; the chat itself is another package's job.
class _MockChat extends StatelessWidget {
  const _MockChat({required this.dark, required this.right});

  final bool dark;
  final bool right;

  @override
  Widget build(BuildContext context) {
    final incoming = dark ? const Color(0xFF2A2A2D) : const Color(0xFFFFFFFF);
    final outgoing = dark ? const Color(0xFF2B5278) : const Color(0xFFEFFDDE);
    Widget bubble(double w, double h, bool out) => Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: w,
        height: h,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: out ? outgoing : incoming,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(out ? 16 : 5),
            bottomRight: Radius.circular(out ? 5 : 16),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          bubble(right ? 220 : 300, 44, false),
          bubble(right ? 180 : 260, 44, true),
          bubble(right ? 260 : 360, 64, false),
          bubble(200, 44, true),
        ],
      ),
    );
  }
}
