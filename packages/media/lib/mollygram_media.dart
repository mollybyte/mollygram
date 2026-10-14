/// Mollygram media: playback of video messages (circles), GIFs, video and
/// voice messages, and later recording.
///
/// Call [MollygramMedia.ensureInitialized] once in `main()` before creating
/// players. The app also needs `media_kit_libs_video` (or the per-platform
/// libs packages) for the native libmpv build.
library;

import 'package:media_kit/media_kit.dart';

export 'src/audio/audio_track_player.dart';
export 'src/circle/circle_player.dart';
export 'src/circle/circle_player_pool.dart';
export 'src/circle/circle_quality.dart';
export 'src/circle/circle_video.dart';
export 'src/circle/media_kit_circle_player.dart';
export 'src/video/looping_video.dart';
export 'src/video/video_player_view.dart';

abstract final class MollygramMedia {
  /// Loads libmpv. Safe to call more than once.
  static void ensureInitialized() => MediaKit.ensureInitialized();
}
