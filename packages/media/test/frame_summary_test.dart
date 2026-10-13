import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_media/frame_timing.dart';

/// Frames at [hz] starting at 0, with optional slow frames by index.
List<FrameSample> frames(
  int count, {
  double hz = 120,
  Map<int, double> rasterMs = const {},
  Set<int> dropped = const {},
}) {
  final period = 1e6 / hz;
  return [
    for (var i = 0; i < count; i++)
      if (!dropped.contains(i))
        FrameSample(
          vsyncUs: (i * period).round(),
          buildMs: 1,
          rasterMs: rasterMs[i] ?? 3,
          totalMs: 5,
        ),
  ];
}

void main() {
  test('a steady 120 Hz run has no missed vsyncs', () {
    final s = FrameSummary.of(frames(240), 120);

    expect(s.frames, 240);
    expect(s.fps, closeTo(120, 0.5));
    expect(s.budgetMs, closeTo(8.33, 0.01));
    expect(s.missedVsyncs, 0);
    expect(s.overBudget, 0);
    expect(s.rasterMax, 3);
  });

  test('dropped frames count as missed vsyncs', () {
    final s = FrameSummary.of(frames(240, dropped: {100, 101, 200}), 120);

    expect(s.missedVsyncs, 3);
    expect(s.missedPct, closeTo(100 * 3 / 240, 0.01));
  });

  test('without a reported refresh rate the vsync interval is used', () {
    final s = FrameSummary.of(frames(165, hz: 165), 0);

    expect(s.vsyncHz, closeTo(165, 1));
    expect(s.budgetMs, closeTo(6.06, 0.05));
  });

  test('long pauses are reported apart from drops', () {
    final a = frames(60);
    final b = [
      for (final f in frames(60))
        FrameSample(
          vsyncUs: f.vsyncUs + 2000000,
          buildMs: f.buildMs,
          rasterMs: f.rasterMs,
          totalMs: f.totalMs,
        ),
    ];
    final s = FrameSummary.of([...a, ...b], 120);

    expect(s.pauses, 1);
    expect(s.missedVsyncs, 0);
  });

  test('an empty run summarizes to zeros', () {
    final s = FrameSummary.of(const [], 120);
    expect(s.frames, 0);
    expect(s.fps, 0);
  });

  group('EventFrames', () {
    test('finds the slow frame right after an event', () {
      // A 26 ms frame 30 frames (250 ms) after the event at frame 120.
      final samples = frames(
        480,
        rasterMs: {150: 26, 400: 40},
        dropped: {151, 152},
      );
      final event = samples.firstWhere((s) => s.vsyncUs >= 1000000).vsyncUs;
      final e = EventFrames.of(samples, [event], 1000 / 120);

      expect(e.events, 1);
      expect(e.frames, 58);
      expect(e.rasterMax, 26);
      expect(e.overBudget, 1);
      expect(e.missedVsyncs, 2);
    });

    test('frames outside the windows are ignored', () {
      final samples = frames(480, rasterMs: {10: 40});
      final e = EventFrames.of(samples, [2000000], 1000 / 120);

      expect(e.rasterMax, 3);
      expect(e.overBudget, 0);
    });

    test('overlapping windows count each frame once', () {
      final samples = frames(240);
      final e = EventFrames.of(samples, [0, 100000], 1000 / 120);

      expect(e.frames, 72);
    });
  });
}
