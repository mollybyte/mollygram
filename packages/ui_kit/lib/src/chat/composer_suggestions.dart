import 'package:flutter/widgets.dart';

import '../glass/glass.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// One row of the popup above the composer, such as a group member for
/// an @mention.
@immutable
class ComposerSuggestion {
  const ComposerSuggestion({
    required this.title,
    this.subtitle = '',
    this.leading,
  });

  final String title;

  /// Such as the @username.
  final String subtitle;

  /// Such as a 28 px avatar.
  final Widget? leading;
}

/// The popup of [suggestions] over the composer. [highlighted] is the row
/// Enter or Tab picks; the composer moves it with the arrow keys.
class ComposerSuggestionList extends StatefulWidget {
  const ComposerSuggestionList({
    super.key,
    required this.suggestions,
    required this.highlighted,
    required this.onPick,
    this.onHover,
  });

  final List<ComposerSuggestion> suggestions;
  final int highlighted;
  final ValueChanged<int> onPick;
  final ValueChanged<int>? onHover;

  static const double rowHeight = 40;

  /// Rows shown before the list scrolls.
  static const int visibleRows = 5;

  @override
  State<ComposerSuggestionList> createState() => _ComposerSuggestionListState();
}

class _ComposerSuggestionListState extends State<ComposerSuggestionList> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(ComposerSuggestionList old) {
    super.didUpdateWidget(old);
    if (old.highlighted != widget.highlighted) _reveal();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the highlighted row in view as the arrow keys move it.
  void _reveal() {
    if (!_scroll.hasClients) return;
    const h = ComposerSuggestionList.rowHeight;
    final top = widget.highlighted * h;
    final position = _scroll.position;
    final target = top < position.pixels
        ? top
        : top + h > position.pixels + position.viewportDimension
        ? top + h - position.viewportDimension
        : null;
    if (target != null) {
      _scroll.jumpTo(target.clamp(0, position.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final suggestions = widget.suggestions;
    return Glass(
      radius: 14,
      padding: const EdgeInsets.all(4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight:
              ComposerSuggestionList.rowHeight *
              ComposerSuggestionList.visibleRows,
        ),
        child: ListView.builder(
          controller: _scroll,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          itemExtent: ComposerSuggestionList.rowHeight,
          itemBuilder: (context, i) {
            final suggestion = suggestions[i];
            final selected = i == widget.highlighted;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => widget.onHover?.call(i),
              child: GestureDetector(
                onTap: () => widget.onPick(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: selected ? c.field : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      if (suggestion.leading != null) ...[
                        suggestion.leading!,
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          suggestion.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(c, weight: FontWeight.w500),
                        ),
                      ),
                      if (suggestion.subtitle.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            suggestion.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mgTextStyle(
                              c,
                              size: MgType.small,
                              color: c.fg2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
