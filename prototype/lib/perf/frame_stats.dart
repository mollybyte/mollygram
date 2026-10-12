import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/scheduler.dart';

/// A single frame from FrameTiming, in milliseconds.
class FrameSample {
  const FrameSample({
    required this.vsyncUs,
    required this.buildMs,
    required this.rasterMs,
    required this.totalMs,
  });

  FrameSample.from(FrameTiming t)
    : vsyncUs = t.timestampInMicroseconds(FramePhase.vsyncStart),
      buildMs = t.buildDuration.inMicroseconds / 1000,
      rasterMs = t.rasterDuration.inMicroseconds / 1000,
      totalMs = t.totalSpan.inMicroseconds / 1000;

  final int vsyncUs;
  final double buildMs;
  final double rasterMs;
  final double totalMs;
}

/// A summary of a set of frames.
class FrameSummary {
  FrameSummary._({
    required this.frames,
    required this.fps,
    required this.vsyncHz,
    required this.budgetMs,
    required this.buildP50,
    required this.buildP95,
    required this.buildMax,
    required this.rasterP50,
    required this.rasterP95,
    required this.rasterMax,
    required this.overBudget,
    required this.missedVsyncs,
    required this.pauses,
  });

  /// [refreshHz] comes from display.refreshRate, or is 0 if the system did
  /// not report it, in which case the rate is taken from the median vsync
  /// interval.
  factory FrameSummary.of(List<FrameSample> s, double refreshHz) {
    if (s.isEmpty) {
      return FrameSummary._(
        frames: 0,
        fps: 0,
        vsyncHz: 0,
        budgetMs: 0,
        buildP50: 0,
        buildP95: 0,
        buildMax: 0,
        rasterP50: 0,
        rasterP95: 0,
        rasterMax: 0,
        overBudget: 0,
        missedVsyncs: 0,
        pauses: 0,
      );
    }
    final sorted = [...s]..sort((a, b) => a.vsyncUs.compareTo(b.vsyncUs));
    final gaps = <double>[];
    var pauses = 0;
    var pausedMs = 0.0;
    for (var i = 1; i < sorted.length; i++) {
      final g = (sorted[i].vsyncUs - sorted[i - 1].vsyncUs) / 1000;
      // Pauses longer than 100 ms are idle time, not drops: the window was
      // hidden, minimized or moved to another display. Count them separately.
      if (g >= 100) {
        pauses++;
        pausedMs += g;
      } else if (g > 0) {
        gaps.add(g);
      }
    }
    final medianGap = gaps.isEmpty ? 0.0 : _pct(gaps, 50);
    final vsyncHz = medianGap > 0 ? 1000 / medianGap : 0.0;
    final hz = refreshHz > 0 ? refreshHz : vsyncHz;
    final budget = hz > 0 ? 1000 / hz : 1000 / 60;

    var missed = 0;
    for (final g in gaps) {
      final n = (g / budget).round() - 1;
      if (n > 0) missed += n;
    }
    final spanMs =
        (sorted.last.vsyncUs - sorted.first.vsyncUs) / 1000 - pausedMs;
    final build = s.map((e) => e.buildMs).toList();
    final raster = s.map((e) => e.rasterMs).toList();
    return FrameSummary._(
      frames: s.length,
      fps: spanMs > 0 ? (s.length - 1) * 1000 / spanMs : 0,
      vsyncHz: vsyncHz,
      budgetMs: budget,
      buildP50: _pct(build, 50),
      buildP95: _pct(build, 95),
      buildMax: build.reduce(math.max),
      rasterP50: _pct(raster, 50),
      rasterP95: _pct(raster, 95),
      rasterMax: raster.reduce(math.max),
      overBudget: s
          .where((e) => e.buildMs > budget || e.rasterMs > budget)
          .length,
      missedVsyncs: missed,
      pauses: pauses,
    );
  }

  final int frames;
  final double fps;

  /// The rate derived from the median interval between frames.
  final double vsyncHz;
  final double budgetMs;
  final double buildP50;
  final double buildP95;
  final double buildMax;
  final double rasterP50;
  final double rasterP95;
  final double rasterMax;

  /// Frames whose build or raster time exceeds the budget of one vsync.
  final int overBudget;

  /// Vsyncs missed during continuous animation: real drops.
  final int missedVsyncs;

  /// Pauses longer than 100 ms. A run with pauses is incomplete and should
  /// be repeated.
  final int pauses;

  double get missedPct => frames + missedVsyncs == 0
      ? 0
      : 100 * missedVsyncs / (frames + missedVsyncs);
}

double _pct(List<double> values, double p) {
  final v = [...values]..sort();
  final i = ((p / 100) * (v.length - 1)).round();
  return v[i.clamp(0, v.length - 1)];
}

/// A FrameTiming subscription: a sliding window for live numbers and
/// recordings for benchmarks.
class FrameStats {
  FrameStats() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static const _window = 240;
  final List<FrameSample> recent = [];
  final List<List<FrameSample>> _recorders = [];
  final List<VoidCallback> _listeners = [];

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final s = FrameSample.from(t);
      recent.add(s);
      for (final r in _recorders) {
        r.add(s);
      }
    }
    if (recent.length > _window) {
      recent.removeRange(0, recent.length - _window);
    }
    for (final l in _listeners) {
      l();
    }
  }

  /// Starts recording all frames and returns the list being filled.
  List<FrameSample> record() {
    final list = <FrameSample>[];
    _recorders.add(list);
    return list;
  }

  void stopRecording(List<FrameSample> list) => _recorders.remove(list);

  void addListener(VoidCallback l) => _listeners.add(l);
  void removeListener(VoidCallback l) => _listeners.remove(l);

  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }
}
