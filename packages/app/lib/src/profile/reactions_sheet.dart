import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import 'manage_sheet.dart';

/// Which reactions members may leave: all of them, some, or none.
enum ReactionsChoice { all, some, none }

/// The reactions allowed in a group or channel.
class ReactionsSheet extends ConsumerStatefulWidget {
  const ReactionsSheet({super.key, required this.settings});

  final ChatSettings settings;

  @override
  ConsumerState<ReactionsSheet> createState() => _ReactionsSheetState();
}

class _ReactionsSheetState extends ConsumerState<ReactionsSheet> {
  late final ChatManagement _management = ref
      .read(telegramSessionProvider)
      .requireValue
      .management;
  late var _choice = switch (widget.settings.reactions) {
    td.ChatAvailableReactionsAll() => ReactionsChoice.all,
    td.ChatAvailableReactionsSome(:final reactions) =>
      reactions.isEmpty ? ReactionsChoice.none : ReactionsChoice.some,
  };
  late final _picked = <String>{
    if (widget.settings.reactions case td.ChatAvailableReactionsSome(
      :final reactions,
    ))
      for (final reaction in reactions)
        if (reaction case td.ReactionTypeEmoji(:final emoji)) emoji,
  };
  var _busy = false;
  var _failed = false;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final max = switch (widget.settings.reactions) {
      td.ChatAvailableReactionsAll(:final maxReactionCount) ||
      td.ChatAvailableReactionsSome(
        :final maxReactionCount,
      ) => maxReactionCount,
    };
    final reactions = switch (_choice) {
      ReactionsChoice.all => td.ChatAvailableReactionsAll(
        maxReactionCount: max,
      ),
      ReactionsChoice.some => td.ChatAvailableReactionsSome(
        reactions: [
          for (final emoji in _management.activeReactions)
            if (_picked.contains(emoji)) td.ReactionTypeEmoji(emoji: emoji),
        ],
        maxReactionCount: max,
      ),
      ReactionsChoice.none => td.ChatAvailableReactionsSome(
        reactions: const [],
        maxReactionCount: max,
      ),
    };
    try {
      await _management.setReactions(widget.settings.chatId, reactions);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    return ManageSheetFrame(
      title: l10n.reactions,
      action: l10n.save,
      busy: _busy,
      error: _failed ? l10n.saveFailed : null,
      onAction: _busy ? null : _save,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChoiceRow<ReactionsChoice>(
              value: _choice,
              onChanged: (value) => setState(() => _choice = value),
              options: [
                (ReactionsChoice.all, l10n.reactionsAll),
                (ReactionsChoice.some, l10n.reactionsSome),
                (ReactionsChoice.none, l10n.reactionsNone),
              ],
            ),
            const SizedBox(height: 6),
            Text(switch (_choice) {
              ReactionsChoice.all => l10n.reactionsAllNote,
              ReactionsChoice.some => l10n.reactionsSomeNote,
              ReactionsChoice.none => l10n.reactionsNoneNote,
            }, style: mgTextStyle(c, size: MgType.caption, color: c.fg2)),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _choice != ReactionsChoice.some
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final emoji in _management.activeReactions)
                            _EmojiChip(
                              emoji: emoji,
                              picked: _picked.contains(emoji),
                              onTap: () => setState(
                                () => _picked.remove(emoji)
                                    ? null
                                    : _picked.add(emoji),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  const _EmojiChip({
    required this.emoji,
    required this.picked,
    required this.onTap,
  });

  final String emoji;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      selected: picked,
      label: emoji,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: picked ? c.accent.withValues(alpha: 0.16) : c.field,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: picked ? c.accent : const Color(0x00000000),
              ),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }
}
