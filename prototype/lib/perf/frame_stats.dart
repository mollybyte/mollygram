import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/scheduler.dart';

/// Один кадр из FrameTiming, в миллисекундах.
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

/// Сводка по набору кадров.
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
  });

  /// [refreshHz] из display.refreshRate; 0, если система его не сообщила,
  /// тогда частота берётся из медианного интервала между vsync.
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
      );
    }
    final sorted = [...s]..sort((a, b) => a.vsyncUs.compareTo(b.vsyncUs));
    final gaps = <double>[];
    for (var i = 1; i < sorted.length; i++) {
      final g = (sorted[i].vsyncUs - sorted[i - 1].vsyncUs) / 1000;
      // Длинные паузы — простой (ничего не анимировалось), не дроп.
      if (g > 0 && g < 100) gaps.add(g);
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
    final spanMs = (sorted.last.vsyncUs - sorted.first.vsyncUs) / 1000;
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
    );
  }

  final int frames;
  final double fps;

  /// Частота по медианному интервалу между кадрами.
  final double vsyncHz;
  final double budgetMs;
  final double buildP50;
  final double buildP95;
  final double buildMax;
  final double rasterP50;
  final double rasterP95;
  final double rasterMax;

  /// Кадры, у которых build или raster дольше бюджета одного vsync.
  final int overBudget;

  /// Пропущенные vsync при непрерывной анимации: настоящие дропы.
  final int missedVsyncs;

  double get missedPct => frames + missedVsyncs == 0
      ? 0
      : 100 * missedVsyncs / (frames + missedVsyncs);
}

double _pct(List<double> values, double p) {
  final v = [...values]..sort();
  final i = ((p / 100) * (v.length - 1)).round();
  return v[i.clamp(0, v.length - 1)];
}

/// Подписка на FrameTiming: скользящее окно для живых цифр и записи
/// для замеров.
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

  /// Начать запись всех кадров; вернуть список, который пополняется.
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
