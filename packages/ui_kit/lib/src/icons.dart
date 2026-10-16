import 'dart:math' as math;

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
  static const settings = MgIconData(
    'settings',
    '<circle cx="12" cy="12" r="3"/>'
        '<path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1'
        'a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1'
        'a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8'
        'l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1'
        'a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8'
        'l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1'
        'a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8'
        'l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4'
        'h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
    stroke: 1.6,
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
  static const camera = MgIconData(
    'camera',
    '<path d="M3 8h4l2-3h6l2 3h4v11H3z"/><circle cx="12" cy="13" r="3.5"/>',
  );
  static const switchCamera = MgIconData(
    'switchCamera',
    '<path d="M3 8h4l2-3h6l2 3h4v11H3z"/>'
        '<path d="M9 12.5a3 3 0 0 1 5.4-1.8M15 13.5a3 3 0 0 1-5.4 1.8"/>'
        '<path d="M14.6 8.8v2h-2M9.4 17.2v-2h2"/>',
  );
  static const lockOpen = MgIconData(
    'lockOpen',
    '<path d="M7 11V8a5 5 0 0 1 9.6-2M5 11h14v9H5z"/>',
  );
  static const chevronUp = MgIconData('chevronUp', '<path d="M6 15l6-6 6 6"/>');
  static const trash = MgIconData(
    'trash',
    '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v5M14 11v5"/>',
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
  static const close = MgIconData(
    'close',
    '<path d="M7 7l10 10M17 7L7 17"/>',
    stroke: 2,
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
  static const failed = MgIconData(
    'failed',
    '<circle cx="12" cy="12" r="8"/><path d="M12 8v4.5M12 16h.01"/>',
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
  // Chat list (TelegramSwift's dialog row and context menu).
  static const pin = MgIconData(
    'pin',
    '<path d="M15 3l6 6-3 1-4 4 1 5-2 2-4-4-5 5-1-1 5-5-4-4 2-2 5 1 4-4z" '
        'fill="currentColor" stroke="none"/>',
  );

  /// Before the title of a group in the chat list.
  static const group = MgIconData(
    'group',
    '<circle cx="9" cy="8" r="3.5"/>'
        '<path d="M2 20a7 7 0 0 1 14 0M16 4.5a3.5 3.5 0 0 1 0 7"/>',
    stroke: 2,
  );

  /// Before the title of a channel in the chat list.
  static const channel = MgIconData(
    'channel',
    '<path d="M4 10v4h3l6 4V6L7 10z"/>',
    stroke: 2,
  );
  static const archive = MgIconData(
    'archive',
    '<rect x="3" y="4" width="18" height="5" rx="1.5"/>'
        '<path d="M5 9v9a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9M10 13h4"/>',
    stroke: 1.7,
  );
  static const file = MgIconData(
    'file',
    '<path d="M7 3h7l5 5v13H7zM14 3v5h5"/>',
  );

  // Emoji and sticker panel: one per section.
  static const recent = MgIconData(
    'recent',
    '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  );
  static const favorite = MgIconData(
    'favorite',
    '<path d="m12 3.5 2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8'
        '-4.3-4.1 5.9-.9z"/>',
  );
  static const animals = MgIconData(
    'animals',
    '<circle cx="5.5" cy="10.5" r="1.8"/><circle cx="9.5" cy="6" r="1.8"/>'
        '<circle cx="14.5" cy="6" r="1.8"/><circle cx="18.5" cy="10.5" r="1.8"/>'
        '<path d="M12 11.5c-3 0-6 4.3-6 6.7a2.4 2.4 0 0 0 3.4 2.2'
        'c1.7-.7 3.5-.7 5.2 0a2.4 2.4 0 0 0 3.4-2.2c0-2.4-3-6.7-6-6.7z"/>',
  );
  static const food = MgIconData(
    'food',
    '<path d="M5 9h12v4a6 6 0 0 1-12 0zM17 10h1a2.5 2.5 0 0 1 0 5h-1.4'
        'M8.5 3v3M11 3v3M13.5 3v3"/>',
  );
  static const travel = MgIconData(
    'travel',
    '<path d="M4.5 17v-5l2-5.5h11l2 5.5v5zM4.5 12h15M6.5 17v2.5M17.5 17v2.5"/>'
        '<path d="M8 14.5h.01M16 14.5h.01" stroke-width="2.4"/>',
  );
  static const activities = MgIconData(
    'activities',
    '<circle cx="12" cy="12" r="9"/>'
        '<path d="M5.6 5.6a9 9 0 0 1 0 12.8M18.4 5.6a9 9 0 0 0 0 12.8"/>',
  );
  static const objects = MgIconData(
    'objects',
    '<path d="M9.5 18h5M10.5 21h3M12 3a6 6 0 0 0-3.6 10.8c.7.5 1.1 1.3 1.1'
        ' 2.1V16h5v-.1c0-.8.4-1.6 1.1-2.1A6 6 0 0 0 12 3z"/>',
  );
  static const symbols = MgIconData(
    'symbols',
    '<path d="M12 20s-7.5-4.6-7.5-10.2A4.3 4.3 0 0 1 12 7.2a4.3 4.3 0 0 1'
        ' 7.5 2.6C19.5 15.4 12 20 12 20z"/>',
  );
  static const flag = MgIconData(
    'flag',
    '<path d="M5.5 21V4M5.5 4.5h12l-2.5 4 2.5 4h-12"/>',
  );
  static const sticker = MgIconData(
    'sticker',
    '<path d="M20 12.5V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h6.5z'
        'M20 12.5h-4.5a3 3 0 0 0-3 3V20"/>',
  );

  static const views = MgIconData(
    'views',
    '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/>'
        '<circle cx="12" cy="12" r="3"/>',
  );
  static const comment = MgIconData(
    'comment',
    '<path d="M12 20a8 8 0 1 0-7.1-4.3L4 20l4.3-.9A8 8 0 0 0 12 20z"/>',
  );
  static const list = MgIconData(
    'list',
    '<path d="M9 6h12M9 12h12M9 18h12"/>'
        '<circle cx="4.5" cy="6" r="1"/>'
        '<circle cx="4.5" cy="12" r="1"/>'
        '<circle cx="4.5" cy="18" r="1"/>',
  );

  // Media viewer.
  static const forward = MgIconData(
    'forward',
    '<path d="M14 5l7 7-7 7M21 12h-9a8 8 0 0 0-8 8"/>',
  );
  static const copy = MgIconData(
    'copy',
    '<rect x="8" y="8" width="12" height="12" rx="2.5"/>'
        '<path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>',
  );
  static const loop = MgIconData(
    'loop',
    '<path d="M17 3l3 3-3 3M20 6H8a4 4 0 0 0-4 4v1M7 21l-3-3 3-3M4 18h12a4 4 0 0 0 4-4v-1"/>',
  );
  static const volume = MgIconData(
    'volume',
    '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/>'
        '<path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11"/>',
  );
  static const muted = MgIconData(
    'muted',
    '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4zM16 9.5l5 5M21 9.5l-5 5"/>',
  );

  static const arrowDown = MgIconData(
    'arrowDown',
    '<path d="M6 9.5l6 6 6-6"/>',
    stroke: 2,
  );
  static const mention = MgIconData(
    'mention',
    '<circle cx="12" cy="12" r="3.6"/>'
        '<path d="M15.6 12v1.4a2.4 2.4 0 0 0 4.8 0V12a8.4 8.4 0 1 0-3.3 6.7"/>',
  );
  static const heart = MgIconData(
    'heart',
    '<path d="M12 19.5s-7.5-4.6-7.5-10A4.3 4.3 0 0 1 12 6.9a4.3 4.3 0 0 1 7.5 2.6'
        'c0 5.4-7.5 10-7.5 10z"/>',
  );

  // Settings lists.
  static const check = MgIconData(
    'check',
    '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  );
  static const plus = MgIconData('plus', '<path d="M12 5v14M5 12h14"/>');

  // Message menu.
  static const reply = MgIconData(
    'reply',
    '<path d="M10 5 3 12l7 7M3 12h9a8 8 0 0 1 8 8"/>',
  );
  static const quote = MgIconData(
    'quote',
    '<path d="M10 7.5C7 8 5 10 5 13.5V17h4.5v-4.5H7M19 7.5c-3 .5-5 2.5-5 6V17h4.5v-4.5H16"/>',
    stroke: 1.6,
  );
  static const edit = MgIconData(
    'edit',
    '<path d="M4 20h4L19.5 8.5a2.1 2.1 0 0 0-3-3L5 17z"/><path d="m14 7 3 3"/>',
  );
  static const link = MgIconData(
    'link',
    '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/>'
        '<path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
  );
  static const select = MgIconData(
    'select',
    '<circle cx="12" cy="12" r="8.5"/><path d="m8.5 12.3 2.4 2.4 4.6-5"/>',
  );
  static const code = MgIconData(
    'code',
    '<path d="m8 7-5 5 5 5M16 7l5 5-5 5"/>',
  );
  static const spoiler = MgIconData(
    'spoiler',
    '<path d="M3 12S6.5 5.5 12 5.5 21 12 21 12s-3.5 6.5-9 6.5S3 12 3 12z"/>'
        '<circle cx="12" cy="12" r="3"/><path d="M4 4l16 16"/>',
  );

  // Context menus (TelegramSwift's menu icons, redrawn as line icons).
  static const pinOutline = MgIconData(
    'pinOutline',
    '<path d="M9 3h6l-1 7 3 3v1H7v-1l3-3zM12 14v7"/>',
  );
  static const unpin = MgIconData(
    'unpin',
    '<path d="M9 3h6l-1 7 3 3v1H7v-1l3-3zM12 14v7M4 4l16 16"/>',
  );
  static const markUnread = MgIconData(
    'markUnread',
    '<path d="M13 5H4v11h5l-5 4v-4M20 11v5H9"/>'
        '<circle cx="18.5" cy="5.5" r="2.5" fill="currentColor" stroke="none"/>',
  );
  static const unarchive = MgIconData(
    'unarchive',
    '<rect x="3" y="4" width="18" height="5" rx="1.5"/>'
        '<path d="M5 9v9a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9M12 17v-5M9.5 14.5'
        'L12 12l2.5 2.5"/>',
    stroke: 1.7,
  );
  static const clear = MgIconData(
    'clear',
    '<path d="M15 4l5 5-9 9H7l-3-3zM11 8l5 5M10 20h10"/>',
  );
  static const leave = MgIconData(
    'leave',
    '<path d="M14 4H5v16h9M10 12h10M17 9l3 3-3 3"/>',
  );
  static const hide = MgIconData(
    'hide',
    '<path d="M3 12s3.5-6.5 9-6.5 9 6.5 9 6.5-3.5 6.5-9 6.5S3 12 3 12z"/>'
        '<circle cx="12" cy="12" r="3"/><path d="M4 4l16 16"/>',
  );
  static const poll = MgIconData(
    'poll',
    '<path d="M5 20V11M12 20V4M19 20v-6"/>',
    stroke: 2,
  );
  static const location = MgIconData(
    'location',
    '<path d="M12 21s-7-6.5-7-12a7 7 0 0 1 14 0c0 5.5-7 12-7 12z"/>'
        '<circle cx="12" cy="9" r="2.5"/>',
  );
  static const folder = MgIconData(
    'folder',
    '<path d="M3 6a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5'
        'a2 2 0 0 1-2-2z"/>',
  );
  static const star = MgIconData(
    'star',
    '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3'
        ' 6.1-.9z"/>',
  );
  static const tag = MgIconData(
    'tag',
    '<path d="M3 12V4h8l10 10-8 8z"/><circle cx="7.5" cy="8.5" r="1.5"/>',
  );

  static const List<MgIconData> all = [
    pinOutline,
    unpin,
    markUnread,
    unarchive,
    clear,
    leave,
    hide,
    poll,
    location,
    folder,
    star,
    tag,
    group,
    channel,
    compose,
    search,
    call,
    ghost,
    panel,
    attach,
    emoji,
    mic,
    camera,
    switchCamera,
    lockOpen,
    chevronUp,
    trash,
    send,
    download,
    downloadAll,
    play,
    pause,
    close,
    back,
    chevron,
    plugin,
    profile,
    appearance,
    summary,
    sent,
    sending,
    readTicks,
    failed,
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
    pin,
    archive,
    recent,
    favorite,
    animals,
    food,
    travel,
    activities,
    objects,
    symbols,
    flag,
    sticker,
    views,
    comment,
    list,
    forward,
    copy,
    loop,
    volume,
    muted,
    arrowDown,
    mention,
    heart,
    check,
    plus,
    reply,
    quote,
    edit,
    link,
    select,
    code,
    spoiler,
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

  /// The thinnest line drawn, in logical pixels.
  static const double minLine = 1.45;

  @override
  Widget build(BuildContext context) {
    final color =
        this.color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFF000000);
    // The strokes are drawn at 24 x 24 and shrink with the icon; small
    // icons keep a line of at least [minLine] px so they don't fade out.
    final width = math.max(stroke ?? icon.stroke, minLine * 24 / size);
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="currentColor" stroke-width="$width" '
      'stroke-linecap="round" stroke-linejoin="round">${icon.body}</svg>',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
