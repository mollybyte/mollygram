import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../chat/message_tile.dart' show SenderAvatar;
import '../session/providers.dart';
import 'manage_sheet.dart';

/// The recent actions of a group's or channel's administrators, newest
/// first, by day, with a way to see one administrator's only.
class AdminLogSheet extends ConsumerStatefulWidget {
  const AdminLogSheet({super.key, required this.chatId, this.now});

  final int chatId;
  final DateTime Function()? now;

  @override
  ConsumerState<AdminLogSheet> createState() => _AdminLogSheetState();
}

class _AdminLogSheetState extends ConsumerState<AdminLogSheet> {
  late final ChatManagement _management = ref
      .read(telegramSessionProvider)
      .requireValue
      .management;
  List<AdminLogEntry>? _entries;
  List<(int, String)> _admins = const [];

  /// The administrator shown alone; 0 for all.
  var _adminId = 0;
  var _hasMore = false;
  var _loading = false;
  var _failed = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(
      _management
          .administrators(widget.chatId)
          .then((admins) {
            if (mounted) setState(() => _admins = admins);
          })
          .catchError((Object _) {}),
    );
  }

  Future<void> _load({bool more = false}) async {
    final generation = more ? _generation : ++_generation;
    setState(() => _loading = true);
    try {
      final page = await _management.recentActions(
        widget.chatId,
        fromEventId: more ? (_entries?.lastOrNull?.id ?? 0) : 0,
        userIds: _adminId == 0 ? const [] : [_adminId],
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries = [if (more) ...?_entries, ...page];
        _hasMore = page.length >= 50;
        _loading = false;
        _failed = false;
      });
    } on Object {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _pickAdmin(Rect anchor) async {
    final l10n = AppLocalizations.of(context);
    await showMgDropdown(
      context,
      anchor: anchor,
      items: [
        MgMenuItem(label: l10n.allAdmins, onSelected: () => _filter(0)),
        for (final (id, name) in _admins)
          MgMenuItem(label: name, onSelected: () => _filter(id)),
      ],
    );
  }

  void _filter(int id) {
    setState(() {
      _adminId = id;
      _entries = null;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final entries = _entries;
    final now = (widget.now ?? DateTime.now)();
    final adminName = _admins
        .where((a) => a.$1 == _adminId)
        .map((a) => a.$2)
        .firstOrNull;
    return ManageSheetFrame(
      title: l10n.recentActions,
      height: 520,
      error: _failed ? l10n.recentActionsFailed : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_admins.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Builder(
                builder: (context) => MgTextButton(
                  label: adminName ?? l10n.allAdmins,
                  onPressed: () {
                    unawaited(_pickAdmin(mgAnchorOf(context)));
                  },
                ),
              ),
            ),
          Expanded(
            child: entries == null
                ? const SizedBox.shrink()
                : entries.isEmpty
                ? SheetNotice(l10n.noRecentActions)
                : ListView(
                    children: [
                      for (final (i, entry) in entries.indexed) ...[
                        if (i == 0 ||
                            !_sameDay(entry.date, entries[i - 1].date))
                          SheetCaption(_day(l10n, entry.date, now)),
                        PersonRow(
                          name: entry.actorName,
                          avatar: SenderAvatar(
                            name: entry.actorName,
                            size: 30,
                            photo: entry.actorPhoto,
                          ),
                          subtitle:
                              '${DateFormat.Hm(l10n.localeName).format(entry.date)}'
                              ' · ${describeAction(l10n, entry)}',
                        ),
                      ],
                      if (_hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Center(
                            child: MgTextButton(
                              label: l10n.showMoreMembers,
                              onPressed: _loading
                                  ? null
                                  : () => unawaited(_load(more: true)),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (entries != null && entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text(
                l10n.recentActionsNote,
                style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
              ),
            ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _day(AppLocalizations l10n, DateTime date, DateTime now) {
  if (_sameDay(date, now)) return l10n.today;
  if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
    return l10n.yesterday;
  }
  return DateFormat.MMMMd(l10n.localeName).format(date);
}

/// One line saying what an administrator did, with the names involved.
String describeAction(AppLocalizations l10n, AdminLogEntry entry) {
  final who = entry.subjectName ?? '';
  String text(td.Message message) => switch (message.content) {
    td.MessageText(:final text) => _quote(text.text),
    _ => l10n.logMedia,
  };
  return switch (entry.action) {
    td.ChatEventMessageEdited(:final newMessage) => l10n.logEditedMessage(
      text(newMessage),
    ),
    td.ChatEventMessageDeleted(:final message) => l10n.logDeletedMessage(
      text(message),
    ),
    td.ChatEventMessagePinned(:final message) => l10n.logPinnedMessage(
      text(message),
    ),
    td.ChatEventMessageUnpinned() => l10n.logUnpinnedMessage,
    td.ChatEventPollStopped() => l10n.logStoppedPoll,
    td.ChatEventMemberJoined() => l10n.logJoined,
    td.ChatEventMemberJoinedByInviteLink(:final inviteLink) =>
      l10n.logJoinedByLink(_linkName(inviteLink)),
    td.ChatEventMemberJoinedByRequest() => l10n.logJoinedByRequest(who),
    td.ChatEventMemberInvited() => l10n.logInvited(who),
    td.ChatEventMemberLeft() => l10n.logLeft,
    td.ChatEventMemberPromoted(:final newStatus) =>
      newStatus is td.ChatMemberStatusAdministrator
          ? l10n.logPromoted(who)
          : l10n.logDemoted(who),
    td.ChatEventMemberRestricted(:final newStatus) => switch (newStatus) {
      td.ChatMemberStatusBanned() => l10n.logBanned(who),
      td.ChatMemberStatusRestricted() => l10n.logRestricted(who),
      _ => l10n.logUnrestricted(who),
    },
    td.ChatEventMemberTagChanged(:final newTag) => l10n.logTitleChanged(
      who,
      newTag,
    ),
    td.ChatEventTitleChanged(:final newTitle) => l10n.logTitleSet(newTitle),
    td.ChatEventDescriptionChanged() => l10n.logDescriptionChanged,
    td.ChatEventPhotoChanged(:final newPhoto) =>
      newPhoto == null ? l10n.logPhotoRemoved : l10n.logPhotoChanged,
    td.ChatEventUsernameChanged(:final newUsername) =>
      newUsername.isEmpty
          ? l10n.logMadePrivate
          : l10n.logMadePublic(newUsername),
    td.ChatEventActiveUsernamesChanged() => l10n.logUsernamesChanged,
    td.ChatEventPermissionsChanged() => l10n.logPermissionsChanged,
    td.ChatEventSlowModeDelayChanged(:final newSlowModeDelay) =>
      newSlowModeDelay == 0
          ? l10n.logSlowModeOff
          : l10n.logSlowModeOn(_duration(l10n, newSlowModeDelay)),
    td.ChatEventLinkedChatChanged(:final newLinkedChatId) =>
      newLinkedChatId == 0 ? l10n.logUnlinked : l10n.logLinked,
    td.ChatEventAvailableReactionsChanged() => l10n.logReactionsChanged,
    td.ChatEventIsAllHistoryAvailableToggled(:final isAllHistoryAvailable) =>
      isAllHistoryAvailable ? l10n.logHistoryShown : l10n.logHistoryHidden,
    td.ChatEventInvitesToggled(:final canInviteUsers) =>
      canInviteUsers ? l10n.logInvitesOn : l10n.logInvitesOff,
    td.ChatEventSignMessagesToggled(:final signMessages) =>
      signMessages ? l10n.logSignaturesOn : l10n.logSignaturesOff,
    td.ChatEventHasProtectedContentToggled(:final hasProtectedContent) =>
      hasProtectedContent ? l10n.logProtectedOn : l10n.logProtectedOff,
    td.ChatEventInviteLinkEdited(:final newInviteLink) => l10n.logLinkEdited(
      _linkName(newInviteLink),
    ),
    td.ChatEventInviteLinkRevoked(:final inviteLink) => l10n.logLinkRevoked(
      _linkName(inviteLink),
    ),
    td.ChatEventInviteLinkDeleted(:final inviteLink) => l10n.logLinkDeleted(
      _linkName(inviteLink),
    ),
    td.ChatEventVideoChatCreated() => l10n.logVideoChatStarted,
    td.ChatEventVideoChatEnded() => l10n.logVideoChatEnded,
    td.ChatEventIsForumToggled(:final isForum) =>
      isForum ? l10n.logTopicsOn : l10n.logTopicsOff,
    td.ChatEventForumTopicCreated(:final topicInfo) => l10n.logTopicCreated(
      topicInfo.name,
    ),
    td.ChatEventForumTopicEdited(:final newTopicInfo) => l10n.logTopicEdited(
      newTopicInfo.name,
    ),
    td.ChatEventForumTopicDeleted(:final topicInfo) => l10n.logTopicDeleted(
      topicInfo.name,
    ),
    td.ChatEventForumTopicToggleIsClosed(:final topicInfo) =>
      l10n.logTopicToggled(topicInfo.name),
    td.ChatEventForumTopicPinned() => l10n.logTopicPinned,
    td.ChatEventStickerSetChanged() => l10n.logStickerSetChanged,
    td.ChatEventMessageAutoDeleteTimeChanged() => l10n.logAutoDeleteChanged,
    _ => l10n.logOther,
  };
}

String _quote(String text) {
  final line = text.replaceAll('\n', ' ').trim();
  return line.length > 60 ? '${line.substring(0, 60)}…' : line;
}

String _linkName(td.ChatInviteLink link) => link.name.isNotEmpty
    ? link.name
    : link.inviteLink.replaceFirst('https://', '');

String _duration(AppLocalizations l10n, int seconds) => switch (seconds) {
  < 60 => l10n.secondsShort(seconds),
  < 3600 => l10n.minutesShort(seconds ~/ 60),
  _ => l10n.hoursShort(seconds ~/ 3600),
};
