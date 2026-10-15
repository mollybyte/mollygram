import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// Line icons of the editor, in the 24x24 style of [MgIcons].
abstract final class EditorIcons {
  static const edit = MgIconData(
    'edit',
    '<path d="M4 20h4.5L19.3 9.2a2.3 2.3 0 0 0-3.3-3.3L5.2 16.7 4 20z"/>'
        '<path d="m14.5 7.5 2 2"/>',
  );
  static const crop = MgIconData(
    'crop',
    '<path d="M7 3v12.5A1.5 1.5 0 0 0 8.5 17H21"/>'
        '<path d="M17 21V8.5A1.5 1.5 0 0 0 15.5 7H3"/>',
  );
  static const rotate = MgIconData(
    'rotate',
    '<rect x="9" y="9" width="11" height="11" rx="2"/>'
        '<path d="M4 13V9.5A5.5 5.5 0 0 1 9.5 4H13"/>'
        '<path d="m10.5 1.5 2.5 2.5-2.5 2.5"/>',
  );
  static const flip = MgIconData(
    'flip',
    '<path d="M12 3v2.5M12 9.5v2M12 15.5v2M12 21v-.5"/>'
        '<path d="M8.5 6.5 3 17.5h5.5z"/>'
        '<path d="M15.5 6.5 21 17.5h-5.5z"/>',
  );
  static const undo = MgIconData(
    'undo',
    '<path d="M8.5 13.5 4 9l4.5-4.5"/>'
        '<path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H10"/>',
  );
  static const redo = MgIconData(
    'redo',
    '<path d="M15.5 13.5 20 9l-4.5-4.5"/>'
        '<path d="M20 9H9.5a5.5 5.5 0 0 0 0 11H14"/>',
  );
  static const landscape = MgIconData(
    'landscape',
    '<rect x="3.5" y="7" width="17" height="10" rx="2"/>',
  );
  static const portrait = MgIconData(
    'portrait',
    '<rect x="7" y="3.5" width="10" height="17" rx="2"/>',
  );
}
