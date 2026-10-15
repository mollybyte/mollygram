import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';

/// The chat sidebar: it lies flat on the window frame, with no glass of its
/// own, 340 px wide.
///
/// From the top: the 44 px title bar row, 8 px below the window's top edge
/// (the system window buttons sit at its left, inside [titleBarInset]; on
/// macOS the runner puts them there, see MainFlutterWindow.swift; keep the
/// two in sync), then the [search] field, the [pinned] chats, the
/// [folders], a [banner] and the chat list [body]. [titleBarFill] lies
/// under the title bar row but the actions (the app puts its window drag
/// area there).
class SidebarIsland extends StatelessWidget {
  const SidebarIsland({
    super.key,
    required this.search,
    required this.body,
    this.pinned,
    this.folders,
    this.banner,
    this.actions = const [],
    this.titleBarInset = 76,
    this.titleBarFill,
  });

  /// Usually an [MgSearchField].
  final Widget search;

  /// The pinned chats under the search field, such as a [PinnedChatGrid];
  /// it brings its own padding.
  final Widget? pinned;

  /// A row over the list, such as [FolderSegments].
  final Widget? folders;

  /// A row between the folders and the list, such as the downloads bar;
  /// null for none. It brings its own padding.
  final Widget? banner;

  /// The chat list; it fills the rest of the sidebar and scrolls inside it.
  final Widget body;
  final List<Widget> actions;
  final double titleBarInset;
  final Widget? titleBarFill;

  static const double width = 340;
  static const double titleBarHeight = 44;

  /// From the window's top edge to the title bar row; the chat cards start
  /// at the same height.
  static const double topInset = 8;

  /// The side padding of everything but the list, whose rows bring their
  /// own.
  static const double gutter = 10;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final fill = titleBarFill;
    return DefaultTextStyle.merge(
      style: mgTextStyle(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: topInset + titleBarHeight,
            child: Stack(
              children: [
                if (fill != null) Positioned.fill(child: fill),
                Positioned(
                  top: topInset,
                  left: titleBarInset,
                  right: gutter - 4,
                  height: titleBarHeight,
                  child: Row(children: [const Spacer(), ...actions]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
            child: search,
          ),
          ?pinned,
          if (folders != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
              child: folders,
            ),
          ?banner,
          Expanded(child: body),
        ],
      ),
    );
  }
}
