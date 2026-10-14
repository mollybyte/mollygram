import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A line icon from the mockups: the body of a 24x24 SVG drawn with
/// `currentColor`, round caps and joins.
@immutable
class MgIconData {
  const MgIconData(this.name, this.body, {this.stroke = 1.8});

  /// A stable name, used in tests and debugging.
  final String name;

  /// SVG elements inside `<svg viewBox="0 0 24 24">`.
  final String body;

  /// Default stroke width at 24x24.
  final double stroke;

  @override
  String toString() => 'MgIconData($name)';
}

/// Every icon the design uses, taken from design/*.dc.html.
abstract final class MgIcons {
  // Sidebar and chat header (Main.dc.html).
  static const compose = MgIconData(
    'compose',
    '<path d="M12 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-6"/>'
        '<path d="M17.5 3.5a2.1 2.1 0 0 1 3 3L12 15l-4 1 1-4z"/>',
    stroke: 1.7,
  );
  static const search = MgIconData(
    'search',
    '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    stroke: 2.2,
  );
  static const call = MgIconData(
    'call',
    '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2'
        'A16 16 0 0 1 3 6a2 2 0 0 1 2-2"/>',
  );
  static const ghost = MgIconData(
    'ghost',
    '<path d="M6 20V10a6 6 0 0 1 12 0v10l-2-1.5-2 1.5-2-1.5-2 1.5-2-1.5z"/>'
        '<path d="M10 10h.01M14 10h.01" stroke-width="2.4"/>',
  );
  static const panel = MgIconData(
    'panel',
    '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M15 4v16"/>',
  );

  // Composer.
  static const attach = MgIconData(
    'attach',
    '<path d="M21 11.5 12.5 20a5 5 0 0 1-7-7l8.5-8.5a3.3 3.3 0 0 1 4.7 4.7'
        'L10.2 17.7a1.7 1.7 0 0 1-2.4-2.4L15.5 7.6"/>',
  );
  static const emoji = MgIconData(
    'emoji',
    '<circle cx="12" cy="12" r="9"/>'
        '<path d="M8.5 14.5a4 4 0 0 0 7 0M9 9.5h.01M15 9.5h.01"/>',
  );
  static const mic = MgIconData(
    'mic',
    '<rect x="9" y="3" width="6" height="11" rx="3"/>'
        '<path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>',
  );
  static const send = MgIconData(
    'send',
    '<path d="M12 19V5M6 11l6-6 6 6"/>',
    stroke: 2.2,
  );

  // Messages and media.
  static const download = MgIconData(
    'download',
    '<path d="M12 5v12M7 12l5 5 5-5"/>',
    stroke: 2,
  );
  static const downloadAll = MgIconData(
    'downloadAll',
    '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
  );
  static const play = MgIconData(
    'play',
    '<path d="M7 4.5v15l13-7.5z" fill="currentColor" stroke="none"/>',
  );
  static const pause = MgIconData(
    'pause',
    '<path d="M8 6h3v12H8zM13 6h3v12h-3z" fill="currentColor" stroke="none"/>',
  );
  static const back = MgIconData('back', '<path d="M15 5l-7 7 7 7"/>');
  static const chevron = MgIconData('chevron', '<path d="M9 5l7 7-7 7"/>');

  // Settings, palette and plugins (Features, Palette, Plugins).
  static const plugin = MgIconData(
    'plugin',
    '<path d="M10 4a2 2 0 1 1 4 0v2h4v4h-2a2 2 0 1 0 0 4h2v4h-4v-2a2 2 0 1 0'
        '-4 0v2H6v-4h2a2 2 0 1 0 0-4H6V6h4z"/>',
  );
  static const profile = MgIconData(
    'profile',
    '<path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM5 20a7 7 0 0 1 14 0"/>',
  );
  static const appearance = MgIconData(
    'appearance',
    '<path d="M12 3a9 9 0 1 0 0 18c1 0 1.5-.7 1.5-1.5 0-1.2-1-1.5-1-2.5s.8-1.5'
        ' 2-1.5H17a4 4 0 0 0 4-4c0-4.4-4-8.5-9-8.5z"/>',
  );
  static const summary = MgIconData(
    'summary',
    '<path d="M17 5H7l6 7-6 7h10"/>',
  );
  static const sent = MgIconData(
    'sent',
    '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    stroke: 2,
  );
  static const sending = MgIconData(
    'sending',
    '<circle cx="12" cy="12" r="8"/><path d="M12 8v4l2.5 2"/>',
    stroke: 2,
  );
  static const readTicks = MgIconData(
    'readTicks',
    '<path d="M1.5 12.5l4.5 4.5L15.5 7.5M11 16.5l.5.5L21 7.5"/>',
    stroke: 2,
  );
  static const read = MgIconData(
    'read',
    '<path d="M2 13l4 4 7-8M10 16l1 1 7-8"/>',
  );
  static const split = MgIconData('split', '<path d="M3 4h18v16H3zM12 4v16"/>');
  static const tabs = MgIconData('tabs', '<path d="M3 5h18v14H3zM3 9h18"/>');
  static const chat = MgIconData('chat', '<path d="M4 5h16v11H9l-5 4z"/>');
  static const video = MgIconData(
    'video',
    '<path d="M4 6h16v12H4zM10 9.5v5l4-2.5z"/>',
  );
  static const translate = MgIconData(
    'translate',
    '<path d="M4 6h9M8.5 4v2M6 6c0 4 3 7 6 8M11 6c0 3-2 6-6 8M13 20l4-9 4 9'
        'M14.5 17h5"/>',
  );
  static const storage = MgIconData(
    'storage',
    '<path d="M5 6c0-1.7 3.1-3 7-3s7 1.3 7 3-3.1 3-7 3-7-1.3-7-3zM5 6v12c0 1.7'
        ' 3.1 3 7 3s7-1.3 7-3V6"/>',
  );
  static const notifications = MgIconData(
    'notifications',
    '<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 20h4"/>',
  );
  static const lock = MgIconData(
    'lock',
    '<path d="M7 11V8a5 5 0 0 1 10 0v3M5 11h14v9H5z"/>',
  );
  static const file = MgIconData(
    'file',
    '<path d="M7 3h7l5 5v13H7zM14 3v5h5"/>',
  );

  static const List<MgIconData> all = [
    compose,
    search,
    call,
    ghost,
    panel,
    attach,
    emoji,
    mic,
    send,
    download,
    downloadAll,
    play,
    pause,
    back,
    chevron,
    plugin,
    profile,
    appearance,
    summary,
    sent,
    sending,
    readTicks,
    read,
    split,
    tabs,
    chat,
    video,
    translate,
    storage,
    notifications,
    lock,
    file,
  ];
}

/// Draws an [MgIconData]. The color comes from [color], or else from the
/// ambient [IconTheme], or else from the [DefaultTextStyle].
class MgIcon extends StatelessWidget {
  const MgIcon(
    this.icon, {
    super.key,
    this.size = 17,
    this.stroke,
    this.color,
    this.semanticLabel,
  });

  final MgIconData icon;
  final double size;

  /// Overrides [MgIconData.stroke].
  final double? stroke;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final color =
        this.color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF000000);
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="currentColor" stroke-width="${stroke ?? icon.stroke}" '
      'stroke-linecap="round" stroke-linejoin="round">${icon.body}</svg>',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
