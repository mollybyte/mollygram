part of 'peer_info_panel.dart';

/// The owner's and administrators' tools for a group or channel, in
/// one group of rows like a System Settings pane: what kind of chat it
/// is, what members may do, who may join, who was removed and what the
/// administrators did lately.
class _ManagementSection extends ConsumerWidget {
  const _ManagementSection({required this.info, required this.rights});

  final PeerInfo info;
  final ChatRights rights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final settings = ref.watch(chatSettingsProvider(info.chatId)).value;
    final channel = info.kind == PeerKind.channel;
    final management = ref
        .read(telegramSessionProvider)
        .requireValue
        .management;
    final chatId = info.chatId;

    Future<void> open(Widget sheet) => showManageSheet<void>(context, sheet);

    /// A change that TDLib confirms with an update, so the row waits on
    /// that rather than flipping ahead of it.
    void change(Future<void> Function() action) =>
        unawaited(action().catchError((Object _) {}));

    // Changing the link needs the owner; the rest needs the right.
    final rows = <Widget>[
      if (settings != null && settings.isSupergroup && rights.isOwner)
        _NavRow(
          label: channel ? l10n.channelType : l10n.groupType,
          value: settings.isPublic ? l10n.publicChat : l10n.privateChat,
          onTap: () => open(ChatTypeSheet(settings: settings)),
        ),
      if (settings != null && !channel && rights.canRestrictMembers)
        _NavRow(
          label: l10n.permissions,
          value: _permissionsSummary(l10n, settings),
          onTap: () => open(PermissionsSheet(settings: settings)),
        ),
      if (settings != null && rights.canChangeInfo)
        _NavRow(
          label: l10n.reactions,
          value: switch (settings.reactions) {
            td.ChatAvailableReactionsAll() => l10n.reactionsAll,
            td.ChatAvailableReactionsSome(:final reactions) =>
              reactions.isEmpty ? l10n.reactionsNone : '${reactions.length}',
          },
          onTap: () => open(ReactionsSheet(settings: settings)),
        ),
      if (settings != null &&
          settings.isSupergroup &&
          rights.canChangeInfo &&
          (channel || settings.linkedChatId != 0))
        _NavRow(
          label: channel ? l10n.discussionGroup : l10n.linkedChannel,
          value: settings.linkedChatId == 0
              ? l10n.none
              : settings.linkedChatTitle,
          onTap: () => open(DiscussionSheet(settings: settings)),
        ),
      if (rights.canManageLinks) ...[
        _NavRow(
          label: l10n.inviteLinks,
          onTap: () => open(InviteLinksSheet(chatId: chatId)),
        ),
        _NavRow(
          label: l10n.joinRequests,
          onTap: () => open(JoinRequestsSheet(chatId: chatId)),
        ),
      ],
      if (settings != null &&
          settings.isSupergroup &&
          rights.canRestrictMembers)
        _NavRow(
          label: l10n.removedUsers,
          value: switch (settings.bannedCount + settings.restrictedCount) {
            0 => '',
            final n => '$n',
          },
          onTap: () => open(RemovedUsersSheet(chatId: chatId)),
        ),
      if (settings != null && settings.canGetEventLog)
        _NavRow(
          label: l10n.recentActions,
          onTap: () => open(AdminLogSheet(chatId: chatId)),
        ),
    ];
    final toggles = <Widget>[
      if (settings != null && settings.canToggleHistory && rights.canChangeInfo)
        ToggleRow(
          label: l10n.historyForNewMembers,
          value: settings.isAllHistoryAvailable,
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          onChanged: (on) => change(
            () => management.setHistoryAvailable(chatId, available: on),
          ),
        ),
      if (settings != null &&
          settings.isSupergroup &&
          !channel &&
          rights.canChangeInfo)
        ToggleRow(
          label: l10n.topics,
          value: settings.isForum,
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          onChanged: (on) =>
              change(() => management.setForum(chatId, forum: on)),
        ),
      // Telegram asks for approval only where anyone can find the group:
      // a public one, or one linked to a channel.
      if (settings != null &&
          settings.isSupergroup &&
          !channel &&
          (settings.isPublic || settings.linkedChatId != 0) &&
          rights.canRestrictMembers)
        ToggleRow(
          label: l10n.approveNewMembers,
          value: settings.joinByRequest,
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          onChanged: (on) =>
              change(() => management.setJoinByRequest(chatId, byRequest: on)),
        ),
    ];
    if (rows.isEmpty && toggles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            l10n.manage,
            style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
          ),
        ),
        if (rows.isNotEmpty) _Group(children: rows),
        if (toggles.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Group(children: toggles),
        ],
      ],
    );
  }
}

/// "8 of 9" permissions on, with slow mode when it is on.
String _permissionsSummary(AppLocalizations l10n, ChatSettings settings) {
  final all = MemberPermission.of(forum: settings.isForum);
  final on = permissionsOf(settings.permissions).intersection(all.toSet());
  final count = l10n.ofCount(on.length, all.length);
  return settings.slowModeDelay == 0
      ? count
      : '$count · ${describeSlowMode(l10n, settings.slowModeDelay)}';
}
