import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'app_state.dart';
import 'chat/chat_pane.dart';
import 'chat/fake_data.dart';
import 'circle/circle_controller.dart';
import 'glass.dart';
import 'perf/benchmark.dart';
import 'perf/frame_stats.dart';
import 'perf/perf_overlay.dart';
import 'sidebar.dart';
import 'theme.dart';
import 'wallpaper.dart';

/// With MG_AUTOBENCH=1 in the environment (or
/// --dart-define=MG_AUTOBENCH=true), runs the benchmark right away, prints
/// the report to stdout and exits.
final autobench =
    const bool.fromEnvironment('MG_AUTOBENCH') ||
    Platform.environment['MG_AUTOBENCH'] == '1';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(PrototypeApp(app: AppState(), circle: CircleController()));
}

class PrototypeApp extends StatefulWidget {
  const PrototypeApp({
    super.key,
    required this.app,
    required this.circle,
    this.chats,
    this.messages,
  });

  final AppState app;
  final CircleController circle;
  final List<FakeChat>? chats;
  final List<FakeMessage>? messages;

  @override
  State<PrototypeApp> createState() => _PrototypeAppState();
}

class _PrototypeAppState extends State<PrototypeApp> {
  late final List<FakeChat> _chats;
  late final List<FakeMessage> _messages;
  final _scroll = ScrollController();
  late final _stats = FrameStats();
  late final _bench = Benchmark(
    stats: _stats,
    scroll: _scroll,
    circle: widget.circle,
    app: widget.app,
    refreshHz: () => WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .display
        .refreshRate,
  );
  int _chat = 1;

  @override
  void initState() {
    super.initState();
    _chats = widget.chats ?? fakeChats;
    _messages = widget.messages ?? buildMessages(5000);
    widget.circle.start();
    if (autobench) _autobench();
  }

  Future<void> _autobench() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    await _bench.runSuite();
    stdout.writeln('MG_BENCH_REPORT_BEGIN');
    stdout.writeln(_bench.report);
    stdout.writeln('MG_BENCH_REPORT_END');
    await stdout.flush();
    exit(0);
  }

  @override
  void dispose() {
    _bench.dispose();
    _stats.dispose();
    _scroll.dispose();
    widget.circle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'Mollygram',
        debugShowCheckedModeBanner: false,
        themeMode: app.themeMode,
        theme: buildTheme(MgColors.light),
        darkTheme: buildTheme(MgColors.darkTheme),
        home: CallbackShortcuts(
          bindings: {
            const SingleActivator(
              LogicalKeyboardKey.keyP,
              meta: true,
              shift: true,
            ): app.toggleOverlay,
          },
          child: Focus(
            autofocus: true,
            child: GlassSettings(
              blur: app.blur,
              child: Material(
                type: MaterialType.transparency,
                child: _Window(
                  sidebar: Sidebar(
                    chats: _chats,
                    selected: _chat,
                    onSelect: (i) => setState(() => _chat = i),
                  ),
                  chat: ChatPane(
                    chat: _chats[_chat],
                    messages: _messages,
                    scroll: _scroll,
                    circle: widget.circle,
                  ),
                  overlay: app.overlay
                      ? PerfOverlay(
                          stats: _stats,
                          bench: _bench,
                          circle: widget.circle,
                          app: app,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The window layout: wallpaper, message list and floating layer. One
/// BackdropGroup covers the whole window so all glass panels share a single
/// backdrop read.
class _Window extends StatelessWidget {
  const _Window({required this.sidebar, required this.chat, this.overlay});

  final Widget sidebar;
  final Widget chat;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return BackdropGroup(
      child: Stack(
        children: [
          const Positioned.fill(child: Wallpaper()),
          Positioned(top: 0, bottom: 0, left: 320, right: 0, child: chat),
          Positioned(top: 8, left: 8, bottom: 8, width: 304, child: sidebar),
          if (overlay != null) Positioned(top: 64, right: 14, child: overlay!),
        ],
      ),
    );
  }
}
