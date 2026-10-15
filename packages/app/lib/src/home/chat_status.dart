import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';

/// Who is doing what in one chat, kept current.
final chatActivityProvider = StreamProvider.family<List<ChatActor>, int>((
  ref,
  chatId,
) {
  final presence = ref.watch(telegramSessionProvider).requireValue.presence;
  return _current(() => presence.activityIn(chatId), [
    presence.changes,
  ]).distinct(_sameActors);
});

/// The status line of one chat, without activity, kept current.
final chatStatusProvider = StreamProvider.family<ChatStatus, int>((
  ref,
  chatId,
) {
  final session = ref.watch(telegramSessionProvider).requireValue;
  final presence = session.presence;
  final chats = session.chatLists;
  ChatStatus status() => switch (chats.store.chat(chatId)) {
    final chat? => presence.statusOf(chat),
    null => const ChatStatusNone(),
  };
  return _current(status, [presence.changes, chats.changes]).distinct();
});

/// Whether the user of a private chat is online, for the dot in the list.
final chatOnlineProvider = StreamProvider.family<bool, int>((ref, chatId) {
  final session = ref.watch(telegramSessionProvider).requireValue;
  final presence = session.presence;
  bool online() => switch (session.chatLists.store.chat(chatId)) {
    final chat? => presence.isOnline(chat, DateTime.now()),
    null => false,
  };
  return _current(online, [
    presence.changes,
    session.chatLists.changes,
  ]).distinct();
});

/// What a chat-list row needs beyond the chat itself: the first name of
/// whoever wrote the last message in a group (a chat's title when a chat
/// posted it; empty when unknown or not a group), and whether Telegram
/// verified the chat. Kept current.
typedef ChatRowInfo = ({String sender, bool verified});

final chatRowInfoProvider = StreamProvider.family<ChatRowInfo, int>((
  ref,
  chatId,
) {
  final session = ref.watch(telegramSessionProvider).requireValue;
  final presence = session.presence;
  final store = session.chatLists.store;
  ChatRowInfo info() {
    final chat = store.chat(chatId);
    if (chat == null) return (sender: '', verified: false);
    final last = chat.lastMessage;
    final sender = !chat.isGroup || last == null || last.isOutgoing
        ? ''
        : last.senderUserId != 0
        ? presence.firstNameOf(last.senderUserId)
        : store.chat(last.senderChatId)?.title ?? '';
    return (sender: sender, verified: presence.isVerified(chat));
  }

  return _current(info, [
    presence.changes,
    session.chatLists.changes,
  ]).distinct();
});

/// Emits [read] now and again after every event of any of [changes].
Stream<T> _current<T>(T Function() read, List<Stream<void>> changes) {
  late final StreamController<T> controller;
  final subscriptions = <StreamSubscription<void>>[];
  controller = StreamController<T>(
    onListen: () {
      for (final stream in changes) {
        subscriptions.add(stream.listen((_) => controller.add(read())));
      }
      controller.add(read());
    },
    onCancel: () async {
      await Future.wait([for (final s in subscriptions) s.cancel()]);
      await controller.close();
    },
  );
  return controller.stream;
}

bool _sameActors(List<ChatActor> a, List<ChatActor> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The words for what [actors] are doing. In a private chat the name is
/// left out ("typing"); in a group it is said who ("Alina is typing").
String formatActivity(
  AppLocalizations l10n,
  List<ChatActor> actors, {
  required bool named,
}) {
  final first = actors.first;
  final action = activityLabel(l10n, first.activity);
  if (!named || first.name.isEmpty) return action;
  return switch (actors.length) {
    1 => l10n.activityByOne(first.name, action),
    2 => l10n.activityByTwo(first.name, actors[1].name),
    final n => l10n.activityByMany(first.name, n - 1),
  };
}

String activityLabel(AppLocalizations l10n, ChatActivity activity) =>
    switch (activity) {
      ChatActivity.typing => l10n.activityTyping,
      ChatActivity.recordingVoice => l10n.activityRecordingVoice,
      ChatActivity.recordingVideoNote => l10n.activityRecordingVideoNote,
      ChatActivity.recordingVideo => l10n.activityRecordingVideo,
      ChatActivity.sendingPhoto => l10n.activitySendingPhoto,
      ChatActivity.sendingVideo => l10n.activitySendingVideo,
      ChatActivity.sendingVoice => l10n.activitySendingVoice,
      ChatActivity.sendingVideoNote => l10n.activitySendingVideoNote,
      ChatActivity.sendingFile => l10n.activitySendingFile,
      ChatActivity.choosingSticker => l10n.activityChoosingSticker,
      ChatActivity.choosingLocation => l10n.activityChoosingLocation,
      ChatActivity.choosingContact => l10n.activityChoosingContact,
      ChatActivity.playingGame => l10n.activityPlayingGame,
      ChatActivity.watchingAnimations => l10n.activityWatchingAnimations,
    };

/// The status line text and whether it is drawn in the accent color
/// (online). Empty when there is nothing to say.
(String, bool) formatChatStatus(
  AppLocalizations l10n,
  ChatStatus status,
  String locale, {
  DateTime? now,
}) {
  now ??= DateTime.now();
  final count = NumberFormat.decimalPattern(locale);
  switch (status) {
    case ChatStatusNone():
      return ('', false);
    case ChatStatusBot():
      return (l10n.statusBot, false);
    case ChatStatusService():
      return (l10n.statusService, false);
    case ChatStatusGroup(:final members, :final online):
      if (members == 0) return (l10n.statusGroup, false);
      final total = l10n.statusMembers(members);
      // "1 online" in a group of one says nothing new.
      if (online < 2) return (total, false);
      return (l10n.statusMembersOnline(total, count.format(online)), false);
    case ChatStatusChannel(:final subscribers):
      if (subscribers == 0) return (l10n.statusChannel, false);
      return (l10n.statusSubscribers(subscribers), false);
    case ChatStatusUser(:final presence):
      return switch (presence) {
        PresenceOnline(:final expires) when expires.isAfter(now) => (
          l10n.statusOnline,
          true,
        ),
        // An online status that ran out reads as "last seen" at its end.
        PresenceOnline(:final expires) => (
          _lastSeen(l10n, expires, locale, now),
          false,
        ),
        PresenceOffline(:final wasOnline) => (
          _lastSeen(l10n, wasOnline, locale, now),
          false,
        ),
        PresenceRecently() => (l10n.statusRecently, false),
        PresenceLastWeek() => (l10n.statusLastWeek, false),
        PresenceLastMonth() => (l10n.statusLastMonth, false),
        PresenceLongAgo() => (l10n.statusLongAgo, false),
      };
  }
}

/// "last seen just now", "… 5 minutes ago", "… today at 9:41", "… yesterday
/// at 22:10" or "… 12.10.2026", as the official client says it.
String _lastSeen(
  AppLocalizations l10n,
  DateTime seen,
  String locale,
  DateTime now,
) {
  final ago = now.difference(seen);
  if (ago.inMinutes < 1) return l10n.statusJustNow;
  if (ago.inMinutes < 60) return l10n.statusMinutesAgo(ago.inMinutes);
  final time = DateFormat.Hm(locale).format(seen);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(seen.year, seen.month, seen.day);
  if (day == today) return l10n.statusToday(time);
  if (today.difference(day).inDays == 1) return l10n.statusYesterday(time);
  return l10n.statusOnDate(DateFormat.yMd(locale).format(seen));
}

/// The left capsule of the chat header: the chat's name and, under it,
/// what someone is doing there, or else its status.
class ChatHeaderTitle extends ConsumerStatefulWidget {
  const ChatHeaderTitle({
    super.key,
    required this.chatId,
    this.titleIcon,
    this.avatar,
    this.subtitle,
    this.onTap,
  });

  final int chatId;

  /// Drawn just before the title, such as a secret chat's lock.
  final Widget? titleIcon;

  /// Replaces the chat's avatar, such as the Saved Messages list button.
  final Widget? avatar;

  /// Shown instead of the presence status when not empty, such as a secret
  /// chat's handshake state.
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  ConsumerState<ChatHeaderTitle> createState() => _ChatHeaderTitleState();
}

class _ChatHeaderTitleState extends ConsumerState<ChatHeaderTitle> {
  /// Redraws "last seen 5 minutes ago" as the minutes go by.
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
    _loadMemberCount();
  }

  @override
  void didUpdateWidget(ChatHeaderTitle old) {
    super.didUpdateWidget(old);
    if (old.chatId != widget.chatId) _loadMemberCount();
  }

  void _loadMemberCount() {
    final session = ref.read(telegramSessionProvider).requireValue;
    final chat = session.chatLists.store.chat(widget.chatId);
    if (chat != null) unawaited(session.presence.loadMemberCount(chat));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final chat = ref.watch(chatEntryProvider(widget.chatId)).value;
    final actors = ref.watch(chatActivityProvider(widget.chatId)).value ?? [];
    final status = ref.watch(chatStatusProvider(widget.chatId)).value;
    final String subtitle;
    final bool accent;
    final fixed = widget.subtitle ?? '';
    if (fixed.isNotEmpty) {
      subtitle = fixed;
      accent = false;
    } else if (actors.isNotEmpty) {
      subtitle = formatActivity(
        l10n,
        actors,
        named: !(chat?.type.isPrivate ?? true),
      );
      accent = true;
    } else {
      (subtitle, accent) = formatChatStatus(
        l10n,
        status ?? const ChatStatusNone(),
        locale,
      );
    }
    return ChatTitleCapsule(
      title: chat?.title ?? '',
      titleIcon: widget.titleIcon,
      avatar: widget.avatar,
      subtitle: subtitle,
      subtitleAccent: accent,
      subtitleActivity: actors.isNotEmpty && fixed.isEmpty,
      onTap: widget.onTap,
    );
  }
}

/// The name and icon of topic `topicId` of forum `chatId`, for the forum's
/// row in the chat list.
final forumTopicInfoProvider =
    FutureProvider.family<td.ForumTopicInfo, (int, int)>((ref, key) {
      final session = ref.watch(telegramSessionProvider).requireValue;
      return session.conversations.topicInfo(key.$1, key.$2);
    });
