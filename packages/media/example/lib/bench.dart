import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:mollygram_media/frame_timing.dart';
import 'package:mollygram_media/mollygram_media.dart';

/// What a single run does with the video messages on screen.
enum Scenario {
  play1('1 circle playing', 1),
  play4('4 circles playing', 4),
  reuse('switch, pooled player', 1),
  recreate('switch, new player', 1);

  const Scenario(this.label, this.circles);
  final String label;
  final int circles;

  bool get switches => this == reuse || this == recreate;
}

class BenchRun {
  const BenchRun(this.quality, this.scenario);
  final CircleQuality quality;
  final Scenario scenario;

  String get label => '${quality.side} | ${scenario.label}';
}

class BenchResult {
  BenchResult(this.run, this.summary, this.events, this.playersCreated);
  final BenchRun run;
  final FrameSummary summary;
  final EventFrames? events;
  final int playersCreated;
}

const runDuration = Duration(seconds: 8);
const switchEvery = Duration(milliseconds: 800);

/// A run spends [runDuration] with the circles playing. A ticker repaints
/// the progress rings every vsync, so Flutter produces a frame on every
/// vsync and a gap between frames is a real drop. In the switch scenarios
/// the circle gets a new source every [switchEvery], either on the same
/// pooled player or on a newly created one, which is what the prototype did
/// when it swapped backends.
class Bench extends ChangeNotifier {
  Bench({required this.refreshHz});

  final double Function() refreshHz;
  final FrameRecorder _frames = FrameRecorder();
  final CirclePlayerPool _pool = CirclePlayerPool(
    create: (side) => MediaKitCirclePlayer(outputSide: side),
    maxIdle: 4,
  );

  /// The circles on screen.
  List<CirclePlayer?> slots = const [];

  /// Drives the progress rings.
  Duration elapsed = Duration.zero;

  BenchRun? current;
  final List<BenchResult> results = [];
  bool running = false;

  static CircleSource sourceFor(CircleQuality q) =>
      CircleSource.asset('assets/circle_${q.side}.mp4');

  List<BenchRun> get suite => [
    for (final q in CircleQuality.values)
      for (final s in Scenario.values) BenchRun(q, s),
  ];

  Future<void> runSuite() async {
    if (running) return;
    running = true;
    results.clear();
    notifyListeners();
    for (final run in suite) {
      results.add(await _run(run));
      notifyListeners();
    }
    current = null;
    running = false;
    notifyListeners();
  }

  Future<BenchResult> _run(BenchRun run) async {
    current = run;
    final side = run.quality.side;
    final source = sourceFor(run.quality);

    // Players are created before measuring starts, so in the reuse
    // scenario nothing is created while frames are recorded.
    if (run.scenario == Scenario.recreate) {
      slots = [_fresh(side)];
    } else {
      slots = [
        for (var i = 0; i < run.scenario.circles; i++) _pool.acquire(side),
      ];
    }
    await Future.wait([for (final p in slots) p!.open(source)]);
    notifyListeners();
    // Let the decoders warm up and the first frames reach the screen.
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    _createdDuringRun = 0;
    final samples = _frames.record();
    final events = <int>[];
    final done = Completer<void>();
    int? startUs;
    var nextSwitch = switchEvery;

    final ticker = Ticker((e) {
      final now =
          SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
      startUs ??= now;
      elapsed = e;
      if (run.scenario.switches && e >= nextSwitch && e < runDuration) {
        nextSwitch += switchEvery;
        events.add(now);
        unawaited(_switch(run.scenario, side, source));
      }
      notifyListeners();
      if (e >= runDuration && !done.isCompleted) done.complete();
    })..start();
    await done.future;
    final endUs =
        SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    ticker.dispose();
    // FrameTiming arrives in batches; wait for the tail.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _frames.stopRecording(samples);

    final inRun = samples
        .where((s) => s.vsyncUs >= startUs! && s.vsyncUs < endUs)
        .toList();
    final summary = FrameSummary.of(inRun, refreshHz());
    final result = BenchResult(
      run,
      summary,
      run.scenario.switches
          ? EventFrames.of(inRun, events, summary.budgetMs)
          : null,
      _createdDuringRun,
    );

    final old = slots;
    slots = const [];
    notifyListeners();
    await SchedulerBinding.instance.endOfFrame;
    for (final p in old) {
      if (p != null) await _drop(p);
    }
    return result;
  }

  Future<void> _switch(Scenario scenario, int side, CircleSource source) async {
    final old = slots.first;
    if (old == null) return;
    if (scenario == Scenario.reuse) {
      // What the app does when the next circle starts: stop, then open the
      // new source on the same player and texture.
      await old.stop();
      await old.open(source);
    } else {
      _createdDuringRun++;
      final fresh = _fresh(side);
      slots = [fresh];
      notifyListeners();
      await SchedulerBinding.instance.endOfFrame;
      await _drop(old);
      await fresh.open(source);
    }
  }

  // Players of the recreate scenario bypass the pool and are disposed.
  final Set<CirclePlayer> _unpooled = {};
  int _createdDuringRun = 0;

  CirclePlayer _fresh(int side) {
    final p = MediaKitCirclePlayer(outputSide: side);
    _unpooled.add(p);
    return p;
  }

  Future<void> _drop(CirclePlayer p) =>
      _unpooled.remove(p) ? p.dispose() : _pool.release(p);

  String report() {
    final b = StringBuffer();
    final mode = kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug';
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    final hz = refreshHz();
    b.writeln('Mollygram media: video message benchmark');
    b.writeln(
      'Build $mode, display ${hz > 0 ? '${hz.toStringAsFixed(0)} Hz' : 'refresh rate unknown'}, '
      'window ${size.width.round()}x${size.height.round()} @${view.devicePixelRatio}x, '
      'H.264 60 fps sources, circle 240 pt',
    );
    if (mode == 'debug') {
      b.writeln('Warning: debug build, the numbers are not representative.');
    }
    b.writeln();
    b.writeln(
      'side | scenario | frames | fps | missed vsyncs | build p95/max | '
      'raster p95/max | after switch: build max / raster max / missed | players created',
    );
    String f(double v) => v.toStringAsFixed(1);
    for (final r in results) {
      final s = r.summary;
      final e = r.events;
      b.writeln(
        '${r.run.label} | ${s.frames} | ${f(s.fps)} | '
        '${s.missedVsyncs} (${f(s.missedPct)}%) | '
        '${f(s.buildP95)}/${f(s.buildMax)} ms | '
        '${f(s.rasterP95)}/${f(s.rasterMax)} ms | '
        '${e == null ? '-' : '${f(e.buildMax)} / ${f(e.rasterMax)} ms / ${e.missedVsyncs}'} | '
        '${r.playersCreated}',
      );
    }
    if (results.any((r) => r.summary.pauses > 0)) {
      b.writeln();
      b.writeln(
        'There were pauses longer than 100 ms: the window was hidden or '
        'moved to another display. Run the benchmark again.',
      );
    }
    return b.toString();
  }

  @override
  void dispose() {
    _frames.dispose();
    for (final p in slots) {
      if (p != null) unawaited(_drop(p));
    }
    unawaited(_pool.dispose());
    super.dispose();
  }
}
