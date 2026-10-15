import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// The line glyph for one of TDLib's folder icon names (see
/// `chatFolderIconNames`); a plain folder for names it doesn't know.
MgIconData folderIcon(String name) => _icons[name] ?? _folder;

const _folder = MgIconData(
  'folder',
  '<path d="M3 7.5A2.5 2.5 0 0 1 5.5 5H9l2 2.2h7.5A2.5 2.5 0 0 1 21 9.7v7.8'
      'a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5z"/>',
);

const _icons = <String, MgIconData>{
  'Custom': _folder,
  'All': MgIconData('folderAll', '<path d="M4 6h16M4 12h16M4 18h16"/>'),
  'Unread': MgIconData(
    'folderUnread',
    '<path d="M20 12.5V17a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 17V8'
        'a2.5 2.5 0 0 1 2.5-2.5H13"/><path d="M4.5 8l7.5 5 3-2"/>'
        '<circle cx="18.5" cy="6" r="2.5"/>',
  ),
  'Unmuted': MgIconData(
    'folderUnmuted',
    '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/>'
        '<path d="M10 20.5a2.2 2.2 0 0 0 4 0"/>',
  ),
  'Private': MgIconData(
    'folderPrivate',
    '<circle cx="12" cy="8.5" r="3.5"/>'
        '<path d="M5 20a7 7 0 0 1 14 0"/>',
  ),
  'Groups': MgIconData(
    'folderGroups',
    '<circle cx="9" cy="9" r="3"/><path d="M3.5 19a5.5 5.5 0 0 1 11 0"/>'
        '<path d="M15.5 6.2a3 3 0 0 1 0 5.6M17 14.2a5.5 5.5 0 0 1 3.5 4.8"/>',
  ),
  'Channels': MgIconData(
    'folderChannels',
    '<path d="M4 10v4h3l7 4V6l-7 4z"/><path d="M17.5 9a4 4 0 0 1 0 6"/>',
  ),
  'Bots': MgIconData(
    'folderBots',
    '<rect x="5" y="8" width="14" height="11" rx="3"/>'
        '<path d="M12 8V5"/><circle cx="12" cy="4" r="1"/>'
        '<path d="M9.5 13v1M14.5 13v1"/>',
  ),
  'Favorite': MgIconData(
    'folderFavorite',
    '<path d="M12 4l2.4 4.9 5.4.8-3.9 3.8.9 5.4L12 16.4l-4.8 2.5.9-5.4'
        '-3.9-3.8 5.4-.8z"/>',
  ),
  'Love': MgIconData(
    'folderLove',
    '<path d="M12 19.5s-7.5-4.4-7.5-9.6A4.1 4.1 0 0 1 12 7.6a4.1 4.1 0 0 1'
        ' 7.5 2.3c0 5.2-7.5 9.6-7.5 9.6z"/>',
  ),
  'Home': MgIconData(
    'folderHome',
    '<path d="M4 11l8-6.5 8 6.5"/><path d="M6 9.5V19h12V9.5"/>'
        '<path d="M10 19v-5h4v5"/>',
  ),
  'Work': MgIconData(
    'folderWork',
    '<rect x="3.5" y="7.5" width="17" height="11.5" rx="2"/>'
        '<path d="M9 7.5V6a1.5 1.5 0 0 1 1.5-1.5h3A1.5 1.5 0 0 1 15 6v1.5'
        'M3.5 12.5h17"/>',
  ),
  'Study': MgIconData(
    'folderStudy',
    '<path d="M2.5 9.5L12 5l9.5 4.5L12 14z"/>'
        '<path d="M6.5 11.5V16c1.5 1.5 3.5 2.2 5.5 2.2s4-.7 5.5-2.2v-4.5'
        'M21.5 9.5V15"/>',
  ),
  'Trade': MgIconData(
    'folderTrade',
    '<path d="M4 17l5-5 3.5 3.5L20 8"/><path d="M15 8h5v5"/>',
  ),
  'Money': MgIconData(
    'folderMoney',
    '<circle cx="12" cy="12" r="8"/>'
        '<path d="M14.8 9.2c-.5-.8-1.5-1.2-2.8-1.2-1.6 0-2.8.8-2.8 2s1.2 1.7'
        ' 2.8 2 2.8.8 2.8 2-1.2 2-2.8 2c-1.3 0-2.3-.4-2.8-1.2M12 6.5v11"/>',
  ),
  'Travel': MgIconData(
    'folderTravel',
    '<rect x="5" y="7.5" width="14" height="11" rx="2"/>'
        '<path d="M9.5 7.5V5.5h5v2M9 18.5v1.5M15 18.5v1.5M9 11v4M15 11v4"/>',
  ),
  'Airplane': MgIconData(
    'folderAirplane',
    '<path d="M10.5 4.5c0-.8.7-1.5 1.5-1.5s1.5.7 1.5 1.5v5l7 4v2l-7-2v4l2'
        ' 1.5V20.5L12 19.5l-3.5 1V19l2-1.5v-4l-7 2v-2l7-4z"/>',
  ),
  'Book': MgIconData(
    'folderBook',
    '<path d="M4 5.5C6.5 4.5 9.5 4.5 12 6c2.5-1.5 5.5-1.5 8-.5V19'
        'c-2.5-1-5.5-1-8 .5-2.5-1.5-5.5-1.5-8-.5z"/><path d="M12 6v13.5"/>',
  ),
  'Note': MgIconData(
    'folderNote',
    '<path d="M9 18V6l10-2v12"/><circle cx="6.5" cy="18" r="2.5"/>'
        '<circle cx="16.5" cy="16" r="2.5"/>',
  ),
  'Light': MgIconData(
    'folderLight',
    '<path d="M9 17.5h6M10 20.5h4"/><path d="M8.5 14.5a6 6 0 1 1 7 0'
        'c-.6.5-1 1.2-1 2v1h-5v-1c0-.8-.4-1.5-1-2z"/>',
  ),
  'Like': MgIconData(
    'folderLike',
    '<path d="M7.5 10.5V19.5H4.5V10.5z"/>'
        '<path d="M7.5 10.5L11 4.5c1.3 0 2.2 1 2 2.3l-.6 3.2h5.1a2 2 0 0 1 2'
        ' 2.4l-1.3 5.6a2 2 0 0 1-2 1.5H7.5"/>',
  ),
  'Palette': MgIconData(
    'folderPalette',
    '<path d="M12 3.5a8.5 8.5 0 1 0 0 17c1.2 0 1.8-.8 1.5-1.8-.4-1.2.3-2.2'
        ' 1.5-2.2h2a3.5 3.5 0 0 0 3.5-3.5c0-5-3.8-9.5-8.5-9.5z"/>'
        '<circle cx="7.5" cy="11" r="1"/><circle cx="10" cy="7.5" r="1"/>'
        '<circle cx="14.5" cy="7.5" r="1"/>',
  ),
  'Game': MgIconData(
    'folderGame',
    '<path d="M7 8h10a4 4 0 0 1 4 4v1.5a3 3 0 0 1-5.4 1.8L14.5 14h-5'
        'l-1.1 1.3A3 3 0 0 1 3 13.5V12a4 4 0 0 1 4-4z"/>'
        '<path d="M7.5 10.5v3M6 12h3M16 11h.01M17.5 13h.01"/>',
  ),
  'Sport': MgIconData(
    'folderSport',
    '<circle cx="12" cy="12" r="8"/>'
        '<path d="M12 4c2.5 2.2 3.8 5 3.8 8s-1.3 5.8-3.8 8M12 4c-2.5 2.2-3.8'
        ' 5-3.8 8s1.3 5.8 3.8 8M4 12h16"/>',
  ),
  'Party': MgIconData(
    'folderParty',
    '<path d="M4 20l4.5-12 7.5 7.5z"/>'
        '<path d="M14 4.5c.5 1 .3 2-.5 2.8M18 7c1 .2 1.7 1 1.8 2M19.5 4.5v.01'
        'M16.5 10.5c1-.6 2.2-.5 3 .3"/>',
  ),
  'Flower': MgIconData(
    'folderFlower',
    '<circle cx="12" cy="9" r="2"/>'
        '<path d="M12 7c0-2.5 2.5-3.5 3.5-1.8 1 1.8-1.5 3.8-1.5 3.8'
        's2.5.4 2.2 2.5c-.3 2-3 1.5-4.2-.5-1.2 2-3.9 2.5-4.2.5-.3-2.1 2.2-2.5'
        ' 2.2-2.5s-2.5-2-1.5-3.8C9.5 3.5 12 4.5 12 7z"/>'
        '<path d="M12 11.5V20M12 17c-1.5-2-3.5-2.5-5-2 .5 2 2.5 3 5 2z"/>',
  ),
  'Cat': MgIconData(
    'folderCat',
    '<path d="M5 9V4l4 3h6l4-3v5a7.5 7.5 0 0 1-7 10.5A7.5 7.5 0 0 1 5 9z"/>'
        '<path d="M9.5 12v.5M14.5 12v.5M11 15.5h2"/>',
  ),
  'Crown': MgIconData(
    'folderCrown',
    '<path d="M4 8l4 4 4-6 4 6 4-4-1.5 10h-13z"/><path d="M5.5 18h13"/>',
  ),
  'Mask': MgIconData(
    'folderMask',
    '<path d="M3.5 8c3-1.5 5.5-1.5 8.5 0 3-1.5 5.5-1.5 8.5 0 0 6-2.5 9-5.5 9'
        '-1.5 0-2.3-1-3-2.5-.7 1.5-1.5 2.5-3 2.5-3 0-5.5-3-5.5-9z"/>'
        '<path d="M7 11.5c.8-.6 1.7-.6 2.5 0M14.5 11.5c.8-.6 1.7-.6 2.5 0"/>',
  ),
  'Setup': MgIconData(
    'folderSetup',
    '<circle cx="12" cy="12" r="3"/>'
        '<path d="M12 3v2.5M12 18.5V21M3 12h2.5M18.5 12H21M5.6 5.6l1.8 1.8'
        'M16.6 16.6l1.8 1.8M5.6 18.4l1.8-1.8M16.6 7.4l1.8-1.8"/>',
  ),
};
