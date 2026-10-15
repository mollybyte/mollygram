/// Editor for photos and videos before they are sent: crop, rotate and
/// mirror, with more tools to come.
///
/// Open it with [showMediaEditor]; it takes a file and hands back an
/// edited file plus the [MediaEdit] that made it, so the same edit can be
/// reopened later on the original.
library;

export 'src/editor.dart' show MediaEditResult, MediaEditorPage, showMediaEditor;
export 'src/model/crop_geometry.dart' show CropHandle, resizeCrop;
export 'src/model/media_edit.dart' show AspectPreset, MediaEdit, unitRect;
export 'src/render/render.dart' show exportEdit;
export 'src/strings.dart';
export 'src/ui/editor_icons.dart';
