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
  static const pen = MgIconData(
    'pen',
    '<path d="M4 20l1-4L16.5 4.5a2.1 2.1 0 0 1 3 3L8 19z"/>'
        '<path d="m14.5 6.5 3 3"/><path d="M5 16l3 3"/>',
  );
  static const marker = MgIconData(
    'marker',
    '<path d="M9 20H4l6-6"/>'
        '<path d="M10 14 17.5 6.5a2 2 0 0 1 3 3L13 17l-3-3z"/>'
        '<path d="M4 21h16"/>',
  );
  static const arrow = MgIconData(
    'arrow',
    '<path d="M5 19 19 5"/><path d="M10 5h9v9"/>',
  );
  static const eraser = MgIconData(
    'eraser',
    '<path d="m7 20-3.5-3.5a2 2 0 0 1 0-2.8l9.2-9.2a2 2 0 0 1 2.8 0l4 4a2 2 0 0 1 0 2.8L12 18.8"/>'
        '<path d="M8.5 9.5 15 16"/><path d="M12 20h8"/>',
  );
  static const text = MgIconData(
    'text',
    '<path d="M5 6V4h14v2"/><path d="M12 4v16"/><path d="M9 20h6"/>',
  );
  static const emoji = MgIconData(
    'emoji',
    '<circle cx="12" cy="12" r="9"/>'
        '<path d="M8.5 14.5a4.5 4.5 0 0 0 7 0"/>'
        '<path d="M9 9.5h.01M15 9.5h.01" stroke-width="2.4"/>',
  );
  static const shapes = MgIconData(
    'shapes',
    '<rect x="3" y="12" width="9" height="9" rx="1.5"/>'
        '<circle cx="15.5" cy="8.5" r="5.5"/>',
  );
  static const rectangle = MgIconData(
    'rectangle',
    '<rect x="3.5" y="5.5" width="17" height="13" rx="2"/>',
  );
  static const ellipse = MgIconData(
    'ellipse',
    '<ellipse cx="12" cy="12" rx="8.5" ry="6.5"/>',
  );
  static const line = MgIconData('line', '<path d="M4 19 20 5"/>');
  static const trash = MgIconData(
    'trash',
    '<path d="M4 7h16"/><path d="M10 11v6M14 11v6"/>'
        '<path d="M6 7l1 13h10l1-13"/><path d="M9 7V4h6v3"/>',
  );
  static const blur = MgIconData(
    'blur',
    '<path d="M12 3.5c3.5 4.2 6 7.3 6 10.3a6 6 0 0 1-12 0c0-3 2.5-6.1 6-10.3z"/>'
        '<path d="M9 14a3 3 0 0 0 3 3"/>',
  );
  static const pixelate = MgIconData(
    'pixelate',
    '<path d="M4 4h5v5H4zM9 9h5v5H9zM14 4h5v5h-5zM4 14h5v5H4zM14 14h5v5h-5z"/>',
  );
  static const adjust = MgIconData(
    'adjust',
    '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/>'
        '<circle cx="16" cy="7" r="2.2"/><circle cx="10" cy="17" r="2.2"/>',
  );
  static const cover = MgIconData(
    'cover',
    '<rect x="3.5" y="5" width="17" height="14" rx="2"/>'
        '<path d="m3.5 16 4.5-4.5 3.5 3.5 2.5-2.5 6.5 6.5"/>'
        '<circle cx="15.5" cy="9.5" r="1.5"/>',
  );
}
