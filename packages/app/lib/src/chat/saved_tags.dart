import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'custom_emoji.dart';

/// The name a Saved Messages tag shows: the label the user gave it, or
/// its emoji alone.
String savedTagName(td.SavedMessagesTag tag) =>
    tag.label.isNotEmpty ? tag.label : reactionKey(tag.tag);

/// The tags on Saved Messages under the chat header, as in Telegram for
/// macOS: a glass capsule with one chip per tag, its emoji, the name the
/// user gave it and how many messages carry it. The [selected] chip is
/// filled with the accent; a click filters the messages by that tag, a
/// right click offers to name it.
class SavedTagBar extends StatelessWidget {
  const SavedTagBar({
    super.key,
    required this.tags,
    required this.selected,
    required this.onSelect,
    required this.onMenu,
  });

  final List<td.SavedMessagesTag> tags;

  /// The tag whose messages are shown, as a [reactionKey].
  final String? selected;
  final void Function(td.SavedMessagesTag tag) onSelect;
  final void Function(td.SavedMessagesTag tag, Offset position) onMenu;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    return BarStrip(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: height,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: tags.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final tag = tags[index];
              final key = reactionKey(tag.tag);
              return _TagChip(
                key: ValueKey('saved-tag-$key'),
                tag: tag,
                reaction: key,
                chosen: key == selected,
                onTap: () => onSelect(tag),
                onMenu: (position) => onMenu(tag, position),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    super.key,
    required this.tag,
    required this.reaction,
    required this.chosen,
    required this.onTap,
    required this.onMenu,
  });

  final td.SavedMessagesTag tag;
  final String reaction;
  final bool chosen;
  final VoidCallback onTap;
  final void Function(Offset position) onMenu;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final fg = chosen ? c.onAccent : c.fg;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onSecondaryTapUp: (details) => onMenu(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: chosen ? c.accent : c.field,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              customReactionIcon(reaction, 16) ??
                  Text(reaction, style: mgTextStyle(c, size: 14, height: 1.2)),
              if (tag.label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  tag.label,
                  style: mgTextStyle(
                    c,
                    size: 13,
                    weight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Text(
                '${tag.count}',
                style: mgTextStyle(
                  c,
                  size: 12,
                  weight: FontWeight.w500,
                  color: chosen ? c.onAccent : c.fg2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
