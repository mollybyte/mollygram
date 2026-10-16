import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'custom_emoji.dart';
import 'describe.dart';
import 'topic_sheet.dart';

/// A forum's topics in the timeline's place: pinned first, each with its
/// icon, name, last message, time and unread count; a click opens one.
class ForumTopicListView extends StatelessWidget {
  const ForumTopicListView({
    super.key,
    required this.topics,
    required this.store,
    required this.onOpen,
    required this.onNearEnd,
    this.onMenu,
    this.onCreate,
    this.topInset = 0,
  });

  final List<td.ForumTopic> topics;
  final ConversationStore store;
  final void Function(td.ForumTopic topic) onOpen;
  final VoidCallback onNearEnd;

  /// A right click on a topic, with where it happened.
  final void Function(td.ForumTopic topic, Offset position)? onMenu;

  /// Set when the user may start a topic: a "New topic" row leads the list.
  final VoidCallback? onCreate;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (topics.isEmpty && onCreate == null) {
      return Center(child: DatePill(l10n.noTopics));
    }
    final lead = onCreate == null ? 0 : 1;
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
        itemCount: topics.length + lead,
        itemBuilder: (context, index) {
          if (index < lead) return _NewTopicRow(onTap: onCreate!);
          final topic = topics[index - lead];
          return _TopicRow(
            topic: topic,
            store: store,
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

/// Shows the actions on [topic] at [position]: pin, close, rename and
/// delete for those who may, each failing with a quiet toast.
Future<void> showTopicMenu(
  BuildContext context, {
  required ConversationController conversations,
  required ForumTopicList list,
  required td.ForumTopic topic,
  required Offset position,
}) async {
  final l10n = AppLocalizations.of(context);
  final store = conversations.store;
  final chatId = topic.info.chatId;
  final id = topic.info.forumTopicId;
  final manage = store.canManageTopics(chatId);
  final own = manage || topic.info.isOutgoing;
  if (!own) return;
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
      if (manage)
        MgMenuItem(
          label: topic.isPinned ? l10n.unpinTopic : l10n.pinTopic,
          icon: topic.isPinned ? MgIcons.unpin : MgIcons.pinOutline,
          onSelected: () => unawaited(
            run(
              () => conversations.setTopicPinned(chatId, id, !topic.isPinned),
            ),
          ),
        ),
      if (!topic.info.isGeneral)
        MgMenuItem(
          label: topic.info.isClosed ? l10n.reopenTopic : l10n.closeTopic,
          icon: topic.info.isClosed ? MgIcons.lockOpen : MgIcons.lock,
          onSelected: () => unawaited(
            run(
              () => conversations.setTopicClosed(
                chatId,
                id,
                !topic.info.isClosed,
              ),
            ),
          ),
        ),
      MgMenuItem(
        label: l10n.editTopic,
        icon: MgIcons.edit,
        onSelected: () =>
            unawaited(showTopicSheet(context, chatId, topic: topic.info)),
      ),
      if (manage && !topic.info.isGeneral)
        MgMenuItem(
          label: l10n.deleteTopic,
          icon: MgIcons.trash,
          destructive: true,
          onSelected: () => unawaited(() async {
            final confirmed = await showMgConfirm(
              context,
              title: l10n.deleteTopic,
              message: l10n.deleteTopicConfirm(topic.info.name),
              confirmLabel: l10n.delete,
              cancelLabel: l10n.cancel,
              destructive: true,
            );
            if (confirmed == null) return;
            await run(() async {
              await conversations.deleteTopic(chatId, id);
              list.remove(id);
            });
          }()),
        ),
    ],
  );
}

/// The row that starts a topic, leading the list for those who may.
class _NewTopicRow extends StatefulWidget {
  const _NewTopicRow({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_NewTopicRow> createState() => _NewTopicRowState();
}

class _NewTopicRowState extends State<_NewTopicRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          label: l10n.newTopic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: _hover ? c.fg.withValues(alpha: 0.06) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: TopicIcon.defaultSize,
                  height: TopicIcon.defaultSize,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+',
                    style: mgTextStyle(
                      c,
                      size: MgType.title,
                      weight: FontWeight.w500,
                      color: c.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.newTopic,
                  style: mgTextStyle(
                    c,
                    weight: FontWeight.w600,
                    color: c.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicRow extends StatefulWidget {
  const _TopicRow({
    required this.topic,
    required this.store,
    required this.onTap,
    this.onMenu,
  });

  final td.ForumTopic topic;
  final ConversationStore store;
  final VoidCallback onTap;
  final void Function(Offset position)? onMenu;

  @override
  State<_TopicRow> createState() => _TopicRowState();
}

class _TopicRowState extends State<_TopicRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final topic = widget.topic;
    final info = topic.info;
    final last = topic.lastMessage;
    final preview = info.isClosed && last == null
        ? l10n.topicClosed
        : last == null
        ? ''
        : _preview(l10n, last);
    final muted = topic.notificationSettings.muteFor > 0;
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
          label: info.name,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _hover ? c.fg.withValues(alpha: 0.06) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                TopicIcon(info: info),
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
                              info.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(
                                c,
                                weight: FontWeight.w600,
                                color: info.isClosed ? c.fg2 : c.fg,
                              ),
                            ),
                          ),
                          if (last != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _time(context, last.date),
                              style: mgTextStyle(
                                c,
                                size: MgType.caption,
                                color: c.fg2,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(c, color: c.fg2),
                            ),
                          ),
                          if (topic.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            UnreadBadge(count: topic.unreadCount, muted: muted),
                          ],
                        ],
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

  String _preview(AppLocalizations l10n, td.Message message) {
    final text = describeContent(l10n, message.content);
    if (message.content is td.MessageForumTopicCreated) return text;
    final name = nameOfSender(
      l10n,
      widget.store,
      MessageSenderId.of(message.senderId),
    );
    return name.isEmpty ? text : '$name: $text';
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

/// A topic's icon: its custom emoji, or a rounded tile in the topic's
/// colour with the first letter of its name, as the official clients draw
/// topics without one.
class TopicIcon extends StatelessWidget {
  const TopicIcon({super.key, required this.info, this.size = defaultSize});

  static const double defaultSize = 36;

  final td.ForumTopicInfo info;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    if (info.icon.customEmojiId != 0) {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child: CustomEmojiIcon(
            id: info.icon.customEmojiId,
            size: size * 7 / 9,
          ),
        ),
      );
    }
    final color = info.isGeneral
        ? c.fg2
        : Color(0xFF000000 | (info.icon.color & 0xFFFFFF));
    final letter = info.isGeneral
        ? '#'
        : info.name.isEmpty
        ? ''
        : info.name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 5 / 18),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: mgTextStyle(
          c,
          size: size < 24 ? size * 0.62 : MgType.title,
          weight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
