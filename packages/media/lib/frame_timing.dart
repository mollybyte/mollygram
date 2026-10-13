/// Frame timing from the engine's FrameTiming reports: fps, percentiles,
/// missed vsyncs and the worst frames after discrete events. Used by the
/// media benchmark and available to the app's performance overlay.
library;

export 'src/frame_timing/frame_recorder.dart';
export 'src/frame_timing/frame_summary.dart';
