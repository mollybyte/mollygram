import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../../l10n/app_localizations.dart';

/// "online", "last seen 5 minutes ago", "last seen yesterday at 21:40", as
/// under a name in the contacts list.
String formatPresence(
  AppLocalizations l10n,
  ContactUser user, {
  required String locale,
  DateTime? now,
}) {
  if (user.isBot) return l10n.presenceBot;
  final presence = user.presence;
  switch (presence.kind) {
    case PresenceKind.online:
      return l10n.presenceOnline;
    case PresenceKind.recently:
      return l10n.presenceRecently;
    case PresenceKind.lastWeek:
      return l10n.presenceLastWeek;
    case PresenceKind.lastMonth:
      return l10n.presenceLastMonth;
    case PresenceKind.unknown:
      return l10n.presenceLongAgo;
    case PresenceKind.offline:
  }
  final seen = presence.wasOnline!;
  now ??= DateTime.now();
  final ago = now.difference(seen);
  if (ago < const Duration(minutes: 1)) return l10n.presenceJustNow;
  if (ago < const Duration(hours: 1)) {
    return l10n.presenceMinutes(ago.inMinutes);
  }
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(seen.year, seen.month, seen.day);
  final time = DateFormat.Hm(locale).format(seen);
  if (day == today) return l10n.presenceToday(time);
  if (day == DateTime(now.year, now.month, now.day - 1)) {
    return l10n.presenceYesterday(time);
  }
  return l10n.presenceDate(DateFormat.yMd(locale).format(seen));
}
