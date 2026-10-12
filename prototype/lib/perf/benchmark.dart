import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../app_state.dart';
import '../circle/circle_controller.dart';
import 'frame_stats.dart';

/// A single benchmark configuration.
class BenchConfig {
  const BenchConfig(this.backend, this.blur);
  final CircleBackend backend;
  final bool blur;

  String get label => '${backend.label}, ${blur ? 'glass' : 'no blur'}';
}

/// The two phases of a single run.
enum BenchPhase {
  still('video message, idle', Duration(seconds: 6)),
  scroll('scrolling under glass', Duration(seconds: 14));

  const BenchPhase(this.label, this.duration);
  final String label;
  final Duration duration;
}

class BenchResult {
  BenchResult(this.config, this.phases);
  final BenchConfig config;
  final Map<BenchPhase, FrameSummary> phases;
}

const benchSuite = [
  BenchConfig(CircleBackend.mediaKit, true),
  BenchConfig(CircleBackend.avFoundation, true),
  BenchConfig(CircleBackend.mediaKit, false),
];

/// The benchmark script: the video message plays, the list stays still for
/// the first 6 s, then for 14 s scrolls up 9000 px and back at a constant
/// speed. The ticker runs the whole time, so Flutter paints every vsync and
/// gaps between frames are real drops.
class Benchmark extends ChangeNotifier {
  Benchmark({
    required this.stats,
    required this.scroll,
    required this.circle,
    required this.app,
    required this.refreshHz,
  });

  final FrameStats stats;
  final ScrollController scroll;
  final CircleController circle;
  final AppState app;
  final double Function() refreshHz;

  static const _distance = 9000.0;

  bool running = false;
  int runIndex = 0;
  int runCount = 0;
  BenchPhase? phase;
  Duration elapsed = Duration.zero;
  final List<BenchResult> results = [];
  String? report;

  String get progress {
    if (!running) return '';
    final p = phase;
    final secs = elapsed.inSeconds;
    return 'Run ${runIndex + 1}/$runCount'
        '${p == null ? '' : ', ${p.label}'}, $secs s';
  }

  Future<void> runSuite([List<BenchConfig> suite = benchSuite]) async {
    if (running) return;
    running = true;
    results.clear();
    report = null;
    runCount = suite.length;
    notifyListeners();
    final wasPlaying = circle.playing;
    final wasBlur = app.blur;
    final wasBackend = circle.backend;
    for (var i = 0; i < suite.length; i++) {
      runIndex = i;
      results.add(await _runOne(suite[i]));
    }
    app.setBlur(wasBlur);
    await circle.setBackend(wasBackend);
    await circle.setPlaying(wasPlaying);
    running = false;
    phase = null;
    report = formatReport();
    notifyListeners();
  }

  Future<BenchResult> _runOne(BenchConfig config) async {
    app.setBlur(config.blur);
    await circle.setBackend(config.backend);
    await circle.setPlaying(true);
    if (scroll.hasClients) scroll.jumpTo(0);
    // Let the player warm up and render its first frames.
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final samples = stats.record();
    final bounds = <BenchPhase, (int, int)>{};
    final done = Completer<void>();
    final stillEnd = BenchPhase.still.duration;
    final total = stillEnd + BenchPhase.scroll.duration;
    int? startUs;
    int? stillEndUs;

    final ticker = Ticker((e) {
      final now =
          SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
      startUs ??= now;
      elapsed = e;
      if (e < stillEnd) {
        phase = BenchPhase.still;
      } else {
        stillEndUs ??= now;
        phase = BenchPhase.scroll;
        final t = (e - stillEnd).inMicroseconds / 1e6;
        final half = BenchPhase.scroll.duration.inMicroseconds / 2e6;
        final pos = t < half
            ? _distance * t / half
            : _distance * (2 * half - t) / half;
        if (scroll.hasClients) {
          scroll.jumpTo(pos.clamp(0, scroll.position.maxScrollExtent));
        }
      }
      notifyListeners();
      if (e >= total && !done.isCompleted) {
        bounds[BenchPhase.still] = (startUs!, stillEndUs!);
        bounds[BenchPhase.scroll] = (stillEndUs!, now);
        done.complete();
      }
    })..start();
    await done.future;
    ticker.dispose();
    // FrameTiming arrives in batches; wait for the tail.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    stats.stopRecording(samples);
    if (scroll.hasClients) scroll.jumpTo(0);

    final hz = refreshHz();
    return BenchResult(config, {
      for (final p in BenchPhase.values)
        p: FrameSummary.of(
          samples
              .where(
                (s) => s.vsyncUs >= bounds[p]!.$1 && s.vsyncUs < bounds[p]!.$2,
              )
              .toList(),
          hz,
        ),
    });
  }

  String formatReport() {
    final b = StringBuffer();
    final mode = kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug';
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    final hz = refreshHz();
    b.writeln('Mollygram prototype: frame benchmark');
    b.writeln(
      'Build $mode, display ${hz > 0 ? '${hz.toStringAsFixed(0)} Hz' : 'refresh rate unknown'}, '
      'window ${size.width.round()}x${size.height.round()} @${view.devicePixelRatio}x, '
      'theme ${app.themeMode.name}',
    );
    if (mode == 'debug') {
      b.writeln('Warning: debug build, the numbers are not representative.');
    }
    b.writeln();
    b.writeln(
      'Run | phase | frames | fps | vsync Hz | build p50/p95/max | raster p50/p95/max | over budget | missed vsyncs | pauses',
    );
    for (final r in results) {
      for (final e in r.phases.entries) {
        final s = e.value;
        String f(double v) => v.toStringAsFixed(1);
        b.writeln(
          '${r.config.label} | ${e.key.label} | ${s.frames} | ${f(s.fps)} | '
          '${f(s.vsyncHz)} | ${f(s.buildP50)}/${f(s.buildP95)}/${f(s.buildMax)} ms | '
          '${f(s.rasterP50)}/${f(s.rasterP95)}/${f(s.rasterMax)} ms | '
          '${s.overBudget} | ${s.missedVsyncs} (${f(s.missedPct)}%) | ${s.pauses}',
        );
      }
    }
    if (results.any((r) => r.phases.values.any((s) => s.pauses > 0))) {
      b.writeln();
      b.writeln(
        'There were pauses longer than 100 ms: the window was hidden, '
        'minimized or moved to another display. Such runs are not '
        'representative; run the benchmark again.',
      );
    }
    return b.toString();
  }
}
