import 'package:flutter/scheduler.dart';

import 'frame_summary.dart';

/// A FrameTiming subscription: a sliding window for live numbers and
/// recordings for benchmarks.
class FrameRecorder {
  FrameRecorder() {
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
