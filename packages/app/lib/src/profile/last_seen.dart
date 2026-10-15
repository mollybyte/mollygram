import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import '../../l10n/app_localizations.dart';

/// The status line under a user's name: "online", "last seen 5 minutes
/// ago", "last seen yesterday at 21:04", "last seen recently".
///
/// [now] is passed in so the text is the same for every row built in one
/// frame, and so tests can fix it.
String describeUserStatus(
  AppLocalizations l10n,
  td.UserStatus status, {
  required DateTime now,
}) {
  switch (status) {
    case td.UserStatusOnline(:final expires):
      // TDLib sends the offline status a little after `expires`; until
      // then the user counts as online.
      final until = DateTime.fromMillisecondsSinceEpoch(expires * 1000);
      if (until.isAfter(now)) return l10n.statusOnline;
      return _lastSeenAt(l10n, until, now);
    case td.UserStatusOffline(:final wasOnline):
      return _lastSeenAt(
        l10n,
        DateTime.fromMillisecondsSinceEpoch(wasOnline * 1000),
        now,
      );
    case td.UserStatusRecently():
      return l10n.lastSeenRecently;
    case td.UserStatusLastWeek():
      return l10n.lastSeenWeek;
    case td.UserStatusLastMonth():
      return l10n.lastSeenMonth;
    case td.UserStatusEmpty():
      return l10n.lastSeenLongAgo;
  }
}

String _lastSeenAt(AppLocalizations l10n, DateTime seen, DateTime now) {
  final ago = now.difference(seen);
  if (ago.inMinutes < 1) return l10n.lastSeenJustNow;
  if (ago.inMinutes < 60) return l10n.lastSeenMinutesAgo(ago.inMinutes);
  final locale = l10n.localeName;
  final time = DateFormat.Hm(locale).format(seen);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(seen.year, seen.month, seen.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return l10n.lastSeenToday(time);
  if (days == 1) return l10n.lastSeenYesterday(time);
  return l10n.lastSeenDate(DateFormat.yMd(locale).format(seen));
}

/// The line under a peer's name in the info panel.
String describePeerStatus(
  AppLocalizations l10n,
  PeerInfo info, {
  required DateTime now,
}) => switch (info.kind) {
  _ when info.isDeleted => '',
  PeerKind.bot => l10n.statusBot,
  PeerKind.user =>
    info.status == null ? '' : describeUserStatus(l10n, info.status!, now: now),
  PeerKind.group => l10n.membersCount(info.memberCount),
  PeerKind.channel => l10n.subscribersCount(info.memberCount),
};

/// Whether [status] means the user is online at [now].
bool isOnline(td.UserStatus? status, DateTime now) =>
    status is td.UserStatusOnline &&
    DateTime.fromMillisecondsSinceEpoch(status.expires * 1000).isAfter(now);

/// A birthday in the reader's language, with the year only when the user
/// shares it.
String describeBirthdate(AppLocalizations l10n, td.Birthdate date) {
  final locale = l10n.localeName;
  final day = DateTime(date.year == 0 ? 2000 : date.year, date.month, date.day);
  return date.year == 0
      ? DateFormat.MMMMd(locale).format(day)
      : DateFormat.yMMMMd(locale).format(day);
}
