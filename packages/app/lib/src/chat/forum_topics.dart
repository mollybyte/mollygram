import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'custom_emoji.dart';
import 'describe.dart';

/// A forum's topics in the timeline's place: pinned first, each with its
/// icon, name, last message, time and unread count; a click opens one.
class ForumTopicListView extends StatelessWidget {
  const ForumTopicListView({
    super.key,
    required this.topics,
    required this.store,
    required this.onOpen,
    required this.onNearEnd,
    this.topInset = 0,
  });

  final List<td.ForumTopic> topics;
  final ConversationStore store;
  final void Function(td.ForumTopic topic) onOpen;
  final VoidCallback onNearEnd;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (topics.isEmpty) return Center(child: DatePill(l10n.noTopics));
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
        itemBuilder: (context, index) => _TopicRow(
          topic: topics[index],
          store: store,
          onTap: () => onOpen(topics[index]),
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
  });

  final td.ForumTopic topic;
  final ConversationStore store;
  final VoidCallback onTap;

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
                _TopicIcon(info: info),
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
class _TopicIcon extends StatelessWidget {
  const _TopicIcon({required this.info});

  final td.ForumTopicInfo info;

  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    if (info.icon.customEmojiId != 0) {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child: CustomEmojiIcon(id: info.icon.customEmojiId, size: 28),
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
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: mgTextStyle(
          c,
          size: MgType.title,
          weight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
