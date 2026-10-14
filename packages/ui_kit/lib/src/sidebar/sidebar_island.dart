import 'package:flutter/widgets.dart';

import '../glass/glass.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// The floating glass island with the chat list (304 px wide in the mockup,
/// 8 px from the window edges, radius 16).
///
/// The 44 px title bar reserves [titleBarInset] on the left for the system
/// window buttons (on macOS the runner centers them in this row, see
/// MainFlutterWindow.swift; keep the two in sync); [titleBarFill] fills the
/// free space (the app puts its window drag area there) and [actions] sit on
/// the right.
class SidebarIsland extends StatelessWidget {
  const SidebarIsland({
    super.key,
    required this.search,
    required this.body,
    this.folders,
    this.actions = const [],
    this.titleBarInset = 76,
    this.titleBarFill,
  });

  /// Usually an [MgSearchField].
  final Widget search;

  /// Usually a [FolderTabBar].
  final Widget? folders;

  /// The chat list; it fills the rest of the island and scrolls inside it.
  final Widget body;
  final List<Widget> actions;
  final double titleBarInset;
  final Widget? titleBarFill;

  static const double width = 304;
  static const double radius = 16;
  static const double titleBarHeight = 44;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Glass(
      radius: radius,
      child: DefaultTextStyle.merge(
        style: mgTextStyle(c),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: titleBarHeight,
              child: Row(
                children: [
                  SizedBox(width: titleBarInset, child: titleBarFill),
                  Expanded(child: titleBarFill ?? const SizedBox()),
                  ...actions,
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: search,
            ),
            if (folders != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: folders,
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
