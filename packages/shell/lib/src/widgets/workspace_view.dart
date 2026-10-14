import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../l10n/shell_strings.dart';
import '../model/workspace.dart';

/// Builds the content of one pane. [chat] is `null` for an empty pane.
typedef PaneBuilder = Widget Function(
  BuildContext context,
  ChatId? chat,
  bool focused,
);

/// The active tab: one pane, or two with a draggable divider.
class WorkspaceView extends StatelessWidget {
  const WorkspaceView({
    super.key,
    required this.controller,
    required this.paneBuilder,
    required this.strings,
  });

  final WorkspaceController controller;
  final PaneBuilder paneBuilder;
  final ShellStrings strings;

  /// Width of the divider's grab area; the visible line is a hairline.
  static const double dividerHitWidth = 8;

  @override
  Widget build(BuildContext context) {
    final tab = controller.value.activeTab;
    Widget pane(int i) => _Pane(
      // Keyed by tab and chat so switching tabs never reuses another chat's
      // state.
      key: ValueKey(('pane', tab.id, i, tab.panes[i])),
      onFocus: () => controller.focusPane(i),
      child: paneBuilder(context, tab.panes[i], tab.focus == i),
    );

    if (!tab.isSplit) return pane(0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final left = (width - dividerHitWidth) * tab.split;
        return Stack(
          children: [
            Positioned(left: 0, top: 0, bottom: 0, width: left, child: pane(0)),
            Positioned(
              left: left + dividerHitWidth,
              top: 0,
              bottom: 0,
              right: 0,
              child: pane(1),
            ),
            Positioned(
              left: left,
              top: 0,
              bottom: 0,
              width: dividerHitWidth,
              child: _Divider(
                label: strings.splitDivider,
                onDrag: (dx) => controller.setSplit(
                  (controller.value.activeTab.split *
                              (width - dividerHitWidth) +
                          dx) /
                      (width - dividerHitWidth),
                ),
                onReset: () => controller.setSplit(WorkspaceTab.defaultSplit),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({super.key, required this.onFocus, required this.child});

  final VoidCallback onFocus;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A click anywhere in a pane gives it focus without stealing the event.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onFocus(),
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({
    required this.label,
    required this.onDrag,
    required this.onReset,
  });

  final String label;
  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      container: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
          onDoubleTap: onReset,
          child: Center(child: Container(width: 0.5, color: c.separator)),
        ),
      ),
    );
  }
}

/// What an empty pane shows until a chat is picked.
class EmptyPane extends StatelessWidget {
  const EmptyPane({super.key, required this.strings});

  final ShellStrings strings;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: c.field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          strings.emptyPane,
          style: TextStyle(fontSize: 13, color: c.fg2),
        ),
      ),
    );
  }
}
