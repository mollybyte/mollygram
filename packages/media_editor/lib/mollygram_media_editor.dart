/// Editor for photos and videos before they are sent.
///
/// Open the photo editor with [showMediaEditor]; it takes a file and hands
/// back an edited file plus the [MediaEdit] that made it, so the same edit
/// can be reopened later on the original. [showVideoEditor] does the same
/// for videos (trim, mute, cover frame) through a [VideoEngine] the app
/// provides.
library;

export 'src/editor.dart' show MediaEditResult, MediaEditorPage, showMediaEditor;
export 'src/model/adjustments.dart';
export 'src/model/crop_geometry.dart' show CropHandle, resizeCrop;
export 'src/model/media_edit.dart' show AspectPreset, MediaEdit, unitRect;
export 'src/model/overlay.dart';
export 'src/model/stroke.dart';
export 'src/model/video_edit.dart';
export 'src/render/overlays.dart' show hitOverlay, overlaySize;
export 'src/render/render.dart' show exportEdit;
export 'src/strings.dart';
export 'src/ui/draw_panel.dart' show brushColors;
export 'src/ui/editor_icons.dart';
export 'src/video/video_engine.dart';
export 'src/video_editor.dart'
    show VideoEditResult, VideoEditorPage, formatTime, showVideoEditor;
