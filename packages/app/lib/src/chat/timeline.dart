import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../../l10n/app_localizations.dart';
import 'message_tile.dart';

/// An entry of the chat list view: a date pill or a row of messages.
sealed class TimelineItem {
  const TimelineItem();

  /// Stable across rebuilds, so rows keep their state while the list
  /// changes around them.
  Object get key;
}

final class TimelineDate extends TimelineItem {
  const TimelineDate(this.day);

  /// Midnight of the day, local time.
  final DateTime day;

  @override
  Object get key => 'day ${day.year}-${day.month}-${day.day}';
}

final class TimelineRow extends TimelineItem {
  const TimelineRow(
    this.row, {
    required this.startsRun,
    required this.endsRun,
    this.startsForwards = false,
  });

  final MessageRow row;
  final bool startsRun;
  final bool endsRun;

  /// The first of forwarded messages in a row, which says so above them.
  final bool startsForwards;

  @override
  Object get key => row.messages.first.keyId;
}

/// Midnight, local time, of the day [message] was sent.
DateTime dayOf(ConversationMessage message) {
  final date = DateTime.fromMillisecondsSinceEpoch(message.date * 1000);
  return DateTime(date.year, date.month, date.day);
}

/// Turns messages (newest first) into list items, newest first: albums
/// become one row, runs from one sender are marked, and each day starts
/// with its date. The oldest day gets its date only once [reachedStart]
/// says no older message will join it. In a channel ([isChannel]) every
/// post stands alone with the channel's name and photo, as in Telegram.
List<TimelineItem> timelineItems(
  List<ConversationMessage> messages, {
  required bool reachedStart,
  bool isChannel = false,
}) {
  final groups = <List<ConversationMessage>>[];
  for (final message in messages) {
    final last = groups.isEmpty ? null : groups.last.last;
    if (last != null &&
        MessageRow.joinsAlbum(message) &&
        MessageRow.joinsAlbum(last) &&
        last.albumId == message.albumId) {
      groups.last.add(message);
    } else {
      groups.add([message]);
    }
  }
  final rows = [for (final g in groups) MessageRow(g)];
  bool together(MessageRow a, MessageRow b) =>
      !isChannel &&
      !a.primary.isService &&
      !b.primary.isService &&
      a.primary.sender == b.primary.sender &&
      dayOf(a.primary) == dayOf(b.primary);

  final items = <TimelineItem>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final newer = i > 0 ? rows[i - 1] : null;
    final older = i + 1 < rows.length ? rows[i + 1] : null;
    final startsRun = older == null || !together(older, row);
    final forwarded = row.primary.message.forwardInfo != null;
    items.add(
      TimelineRow(
        row,
        startsRun: startsRun,
        endsRun: newer == null || !together(row, newer),
        startsForwards:
            forwarded &&
            (startsRun || older.primary.message.forwardInfo == null),
      ),
    );
    final day = dayOf(row.primary);
    if (older == null ? reachedStart : dayOf(older.primary) != day) {
      items.add(TimelineDate(day));
    }
  }
  return items;
}

/// "Today", "Yesterday", "14 October", "14 October 2025".
String formatDay(
  AppLocalizations l10n,
  DateTime day,
  String locale, {
  DateTime? now,
}) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return l10n.today;
  if (difference == 1) return l10n.yesterday;
  if (day.year == now.year) return DateFormat.MMMMd(locale).format(day);
  return DateFormat.yMMMMd(locale).format(day);
}
