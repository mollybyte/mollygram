import 'dart:math' as math;
import 'dart:ui';

/// A single frame from [FrameTiming], in milliseconds.
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

  /// When the frame's vsync started, in microseconds.
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

/// The worst frames right after discrete events, such as a player being
/// created or a source being opened.
///
/// Percentiles over a whole run hide a single slow frame per event, which is
/// exactly what a recreated player costs; this looks only at the frames in
/// the window after each event.
class EventFrames {
  EventFrames._({
    required this.events,
    required this.frames,
    required this.buildMax,
    required this.rasterMax,
    required this.overBudget,
    required this.missedVsyncs,
  });

  /// [eventsUs] are vsync timestamps in microseconds, from the same clock
  /// as [FrameSample.vsyncUs].
  factory EventFrames.of(
    List<FrameSample> samples,
    List<int> eventsUs,
    double budgetMs, {
    Duration window = const Duration(milliseconds: 500),
  }) {
    final sorted = [...samples]..sort((a, b) => a.vsyncUs.compareTo(b.vsyncUs));
    final picked = <FrameSample>{};
    var missed = 0;
    for (final e in eventsUs) {
      final end = e + window.inMicroseconds;
      final inWindow = [
        for (final s in sorted)
          if (s.vsyncUs >= e && s.vsyncUs < end) s,
      ];
      picked.addAll(inWindow);
      for (var i = 1; i < inWindow.length; i++) {
        final gap = (inWindow[i].vsyncUs - inWindow[i - 1].vsyncUs) / 1000;
        if (gap >= 100 || budgetMs <= 0) continue;
        final n = (gap / budgetMs).round() - 1;
        if (n > 0) missed += n;
      }
    }
    double maxOf(double Function(FrameSample) f) =>
        picked.isEmpty ? 0 : picked.map(f).reduce(math.max);
    return EventFrames._(
      events: eventsUs.length,
      frames: picked.length,
      buildMax: maxOf((s) => s.buildMs),
      rasterMax: maxOf((s) => s.rasterMs),
      overBudget: picked
          .where((s) => s.buildMs > budgetMs || s.rasterMs > budgetMs)
          .length,
      missedVsyncs: missed,
    );
  }

  final int events;
  final int frames;
  final double buildMax;
  final double rasterMax;

  /// Frames after events whose build or raster time exceeds one vsync.
  final int overBudget;

  /// Vsyncs missed right after events.
  final int missedVsyncs;
}
