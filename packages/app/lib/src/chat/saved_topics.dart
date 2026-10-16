import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'describe.dart';
import 'message_tile.dart';

/// The name of a Saved Messages topic: the chat the messages came from,
/// the user's own notes, or a hidden author.
String savedTopicName(
  AppLocalizations l10n,
  ConversationStore store,
  td.SavedMessagesTopic topic,
) => switch (topic.type) {
  td.SavedMessagesTopicTypeMyNotes() => l10n.savedMyNotes,
  td.SavedMessagesTopicTypeAuthorHidden() => l10n.savedHiddenAuthor,
  td.SavedMessagesTopicTypeSavedFromChat(:final chatId) =>
    store.nameOf(MessageSenderId.chat(chatId)) ?? '',
};

/// Saved Messages as the chats they came from, in the timeline's place:
/// pinned first, each with its avatar, name, last message and time; a
/// click opens one.
class SavedTopicListView extends StatelessWidget {
  const SavedTopicListView({
    super.key,
    required this.topics,
    required this.store,
    required this.myId,
    required this.onOpen,
    required this.onNearEnd,
    this.onMenu,
    this.topInset = 0,
  });

  final List<td.SavedMessagesTopic> topics;
  final ConversationStore store;

  /// The signed-in user, whose avatar stands for their own notes.
  final int? myId;
  final void Function(td.SavedMessagesTopic topic) onOpen;
  final VoidCallback onNearEnd;

  /// A right click on a topic, with where it happened.
  final void Function(td.SavedMessagesTopic topic, Offset position)? onMenu;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (topics.isEmpty) return Center(child: DatePill(l10n.noMessages));
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.extentAfter < 300) {
          onNearEnd();
        }
        return false;
      },
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(8, topInset + 8, 8, 8),
        itemCount: topics.length,
        itemBuilder: (context, index) {
          final topic = topics[index];
          return _SavedTopicRow(
            key: ValueKey('saved-topic-${topic.id}'),
            topic: topic,
            store: store,
            myId: myId,
            onTap: () => onOpen(topic),
            onMenu: onMenu == null
                ? null
                : (position) => onMenu!(topic, position),
          );
        },
      ),
    );
  }
}

/// Shows the actions on a Saved Messages [topic] at [position]: pin or
/// unpin it, or delete every message saved from it after asking.
Future<void> showSavedTopicMenu(
  BuildContext context, {
  required ConversationController conversations,
  required SavedTopicList list,
  required td.SavedMessagesTopic topic,
  required Offset position,
}) async {
  final l10n = AppLocalizations.of(context);
  final name = savedTopicName(l10n, conversations.store, topic);
  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      if (context.mounted) showMgToast(context, l10n.topicActionFailed);
    }
  }

  await showMgMenu(
    context,
    position: position,
    items: [
      MgMenuItem(
        label: topic.isPinned ? l10n.menuUnpin : l10n.menuPin,
        icon: topic.isPinned ? MgIcons.unpin : MgIcons.pinOutline,
        onSelected: () => unawaited(
          run(
            () => conversations.setSavedTopicPinned(topic.id, !topic.isPinned),
          ),
        ),
      ),
      MgMenuItem(
        label: l10n.menuDelete,
        icon: MgIcons.trash,
        destructive: true,
        onSelected: () => unawaited(() async {
          final confirmed = await showMgConfirm(
            context,
            title: l10n.menuDelete,
            message: l10n.deleteSavedTopicConfirm(name),
            confirmLabel: l10n.delete,
            cancelLabel: l10n.cancel,
            destructive: true,
          );
          if (confirmed == null) return;
          await run(() async {
            await conversations.deleteSavedTopic(topic.id);
            list.remove(topic.id);
          });
        }()),
      ),
    ],
  );
}

class _SavedTopicRow extends StatefulWidget {
  const _SavedTopicRow({
    super.key,
    required this.topic,
    required this.store,
    required this.myId,
    required this.onTap,
    this.onMenu,
  });

  final td.SavedMessagesTopic topic;
  final ConversationStore store;
  final int? myId;
  final VoidCallback onTap;
  final void Function(Offset position)? onMenu;

  @override
  State<_SavedTopicRow> createState() => _SavedTopicRowState();
}

class _SavedTopicRowState extends State<_SavedTopicRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final topic = widget.topic;
    final store = widget.store;
    final name = savedTopicName(l10n, store, topic);
    final last = topic.lastMessage;
    final sender = switch (topic.type) {
      td.SavedMessagesTopicTypeSavedFromChat(:final chatId) =>
        MessageSenderId.chat(chatId),
      td.SavedMessagesTopicTypeMyNotes() when widget.myId != null =>
        MessageSenderId.user(widget.myId!),
      _ => null,
    };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onSecondaryTapUp: widget.onMenu == null
            ? null
            : (details) => widget.onMenu!(details.globalPosition),
        child: Semantics(
          button: true,
          label: name,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _hover ? c.fg.withValues(alpha: 0.06) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SenderAvatar(
                  name: name,
                  photo: sender == null ? null : store.photoOf(sender),
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(c, weight: FontWeight.w600),
                            ),
                          ),
                          if (topic.isPinned)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                l10n.menuPin,
                                style: mgTextStyle(
                                  c,
                                  size: MgType.caption,
                                  color: c.fg2,
                                ),
                              ),
                            ),
                          if (last != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                _time(context, last.date),
                                style: mgTextStyle(
                                  c,
                                  size: MgType.caption,
                                  color: c.fg2,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (last != null)
                        Text(
                          describeContent(l10n, last.content),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(c, color: c.fg2),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _time(BuildContext context, int date) {
    final when = DateTime.fromMillisecondsSinceEpoch(date * 1000);
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    if (when.year == now.year &&
        when.month == now.month &&
        when.day == now.day) {
      return DateFormat.Hm(locale).format(when);
    }
    if (now.difference(when).inDays < 7) {
      return DateFormat.E(locale).format(when);
    }
    return DateFormat.MMMd(locale).format(when);
  }
}
