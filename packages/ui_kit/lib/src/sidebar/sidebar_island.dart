import 'package:flutter/widgets.dart';

import '../glass/glass.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'folder_rail.dart';

/// The floating glass island with the folder rail and the chat list
/// (360 px wide: an 80 px [FolderRail] and the list column, 8 px from the
/// window edges, radius 16).
///
/// The system window buttons sit over the rail's top, centred in the
/// 44 px title bar row (on macOS the runner puts them there, see
/// MainFlutterWindow.swift; keep the two in sync). In the list column that
/// row holds the [search] field and the [actions]; [titleBarFill] fills the
/// rail's top (the app puts its window drag area there).
///
/// Without a [rail] the column takes the whole island and the title bar
/// reserves [titleBarInset] on the left for the window buttons instead.
class SidebarIsland extends StatelessWidget {
  const SidebarIsland({
    super.key,
    required this.search,
    required this.body,
    this.rail,
    this.folders,
    this.banner,
    this.actions = const [],
    this.titleBarInset = 76,
    this.titleBarFill,
  });

  /// Usually a [FolderRail].
  final Widget? rail;

  /// Usually an [MgSearchField].
  final Widget search;

  /// A row under the title bar, such as a [FolderTabBar] when there is no
  /// rail.
  final Widget? folders;

  /// A row between the folders and the list, such as the downloads bar;
  /// null for none. It brings its own padding.
  final Widget? banner;

  /// The chat list; it fills the rest of the island and scrolls inside it.
  final Widget body;
  final List<Widget> actions;
  final double titleBarInset;
  final Widget? titleBarFill;

  static const double width = FolderRail.width + 280;
  static const double radius = 16;
  static const double titleBarHeight = 44;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final rail = this.rail;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: titleBarHeight,
          child: rail != null
              ? Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(child: search),
                    const SizedBox(width: 4),
                    ...actions,
                    const SizedBox(width: 8),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(width: titleBarInset, child: titleBarFill),
                    Expanded(child: titleBarFill ?? const SizedBox()),
                    ...actions,
                    const SizedBox(width: 8),
                  ],
                ),
        ),
        if (rail == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: search,
          ),
        if (folders != null)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: folders),
        ?banner,
        Expanded(child: body),
      ],
    );
    return Glass(
      radius: radius,
      child: DefaultTextStyle.merge(
        style: mgTextStyle(c),
        child: rail == null
            ? column
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  rail,
                  Container(width: 1, color: c.separator),
                  Expanded(child: column),
                ],
              ),
      ),
    );
  }
}
