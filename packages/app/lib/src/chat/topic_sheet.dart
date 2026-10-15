import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../profile/manage_sheet.dart';
import '../session/providers.dart';
import 'media_content.dart';

/// Asks for a topic's name and icon: a new one in forum [chatId], or new
/// ones for [topic]. The icon is a coloured tile with the name's first
/// letter or one of the custom emoji TDLib offers to everyone.
Future<void> showTopicSheet(
  BuildContext context,
  int chatId, {
  td.ForumTopicInfo? topic,
}) => showManageSheet<void>(context, TopicSheet(chatId: chatId, topic: topic));

class TopicSheet extends ConsumerStatefulWidget {
  const TopicSheet({super.key, required this.chatId, this.topic});

  final int chatId;
  final td.ForumTopicInfo? topic;

  @override
  ConsumerState<TopicSheet> createState() => _TopicSheetState();
}

class _TopicSheetState extends ConsumerState<TopicSheet> {
  late final _name = TextEditingController(text: widget.topic?.name ?? '');
  var _busy = false;
  var _failed = false;
  String? _nameError;

  /// The custom emoji on the icon; 0 for the coloured tile.
  late int _emojiId = widget.topic?.icon.customEmojiId ?? 0;

  /// The tile's colour, one of the six TDLib knows.
  late int _color =
      widget.topic?.icon.color ?? ConversationController.topicColors.first;

  List<td.Sticker> _icons = const [];

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    unawaited(_loadIcons());
  }

  Future<void> _loadIcons() async {
    final session = ref.read(telegramSessionProvider).asData?.value;
    if (session == null) return;
    final List<td.Sticker> icons;
    try {
      icons = await session.conversations.topicDefaultIcons();
    } on Object {
      return;
    }
    if (mounted) setState(() => _icons = icons);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = l10n.topicNameRequired);
      return;
    }
    final session = ref.read(telegramSessionProvider).asData?.value;
    if (session == null) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      if (widget.topic case final topic?) {
        await session.conversations.editTopic(
          widget.chatId,
          topic.forumTopicId,
          name: name,
          customEmojiId: _emojiId == topic.icon.customEmojiId ? null : _emojiId,
        );
      } else {
        await session.conversations.createTopic(
          widget.chatId,
          name,
          color: _color,
          customEmojiId: _emojiId,
        );
      }
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.topic != null;
    return ManageSheetFrame(
      title: editing ? l10n.editTopic : l10n.newTopic,
      action: editing ? l10n.save : l10n.create,
      busy: _busy,
      error: _failed
          ? editing
                ? l10n.topicActionFailed
                : l10n.createFailed
          : null,
      onAction: _busy ? null : () => unawaited(_submit()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MgUnderlineField(
              controller: _name,
              hintText: l10n.topicName,
              autofocus: true,
              fontSize: 14,
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              onSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // A topic's colour is set once; editing offers its own tile.
                for (final color
                    in editing ? [_color] : ConversationController.topicColors)
                  _IconTile(
                    key: ValueKey('topic-color-$color'),
                    selected: _emojiId == 0 && _color == color,
                    onTap: () => setState(() {
                      _emojiId = 0;
                      _color = color;
                    }),
                    child: _ColorTile(color: color, name: _name.text),
                  ),
                for (final icon in _icons)
                  if (icon.fullType case td.StickerFullTypeCustomEmoji(
                    :final customEmojiId,
                  ))
                    _IconTile(
                      key: ValueKey('topic-icon-$customEmojiId'),
                      selected: _emojiId == customEmojiId,
                      onTap: () => setState(() => _emojiId = customEmojiId),
                      child: StickerContent(
                        sticker: icon,
                        side: 28,
                        animate: false,
                        lazy: true,
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One choice of icon: a 36 px tile with an accent ring when selected.
class _IconTile extends StatelessWidget {
  const _IconTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? c.accent : const Color(0x00000000),
              width: 2,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// The coloured tile with the topic name's first letter, as the topic
/// list draws it.
class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.color, required this.name});

  final int color;
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final tint = Color(0xFF000000 | (color & 0xFFFFFF));
    final trimmed = name.trim();
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        trimmed.isEmpty ? '' : trimmed.characters.first.toUpperCase(),
        style: mgTextStyle(c, weight: FontWeight.w600, color: tint),
      ),
    );
  }
}
