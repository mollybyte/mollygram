part of 'peer_info_panel.dart';

/// The members of a group or the subscribers of a channel: the owner and
/// administrators first, then the others online first, with a search and
/// more pages on request. A right click on a member offers what the user
/// may do to them.
class _MembersSection extends ConsumerStatefulWidget {
  const _MembersSection({
    super.key,
    required this.info,
    required this.rights,
    required this.now,
    required this.onMember,
  });

  final PeerInfo info;

  /// The user's own rights, which bound the rights they can give.
  final ChatRights rights;
  final DateTime now;
  final ValueChanged<int> onMember;

  @override
  ConsumerState<_MembersSection> createState() => _MembersSectionState();
}

class _MembersSectionState extends ConsumerState<_MembersSection> {
  late final ChatManagement _management = ref
      .read(telegramSessionProvider)
      .requireValue
      .management;
  final _search = TextEditingController();
  StreamSubscription<int>? _changes;
  Timer? _debounce;

  List<ManagedMember> _members = const [];
  var _hasMore = false;
  var _nextOffset = 0;
  var _loading = false;

  /// What went wrong last: loading a page or a change to a member.
  String? _error;

  /// Bumped by every new search, so an older answer is dropped.
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    // The first members the panel already has show until the full list
    // with what the user may do comes.
    _members = [
      for (final member in widget.info.members)
        ManagedMember(
          userId: member.userId,
          name: member.name,
          status: member.status,
          role: member.role,
          photo: member.photo,
          isBot: member.isBot,
        ),
    ];
    _changes = _management.changes
        .where((id) => id == widget.info.chatId)
        .listen((_) => unawaited(_load(refresh: true)));
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// The first page for the current search, or the next one with [more].
  /// With [refresh], everything shown so far is asked for again, so a
  /// change to one member doesn't fold the list back to its first page.
  Future<void> _load({bool more = false, bool refresh = false}) async {
    final generation = more ? _generation : ++_generation;
    setState(() => _loading = true);
    try {
      final page = await _management.members(
        widget.info.chatId,
        query: _search.text,
        offset: more ? _nextOffset : 0,
        limit: refresh
            ? _nextOffset.clamp(ChatManagement.pageSize, 200)
            : ChatManagement.pageSize,
      );
      if (!mounted || generation != _generation) return;
      final known = {if (more) ..._members.map((m) => m.userId)};
      setState(() {
        _members = [
          if (more) ..._members,
          for (final member in page.members)
            if (known.add(member.userId)) member,
        ];
        _hasMore = page.hasMore;
        _nextOffset = page.nextOffset;
        _loading = false;
        _error = null;
      });
    } on Object {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context).membersFailed;
        });
      }
    }
  }

  void _onQuery(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_load()),
    );
  }

  Future<void> _menu(ManagedMember member, Offset position) async {
    final l10n = AppLocalizations.of(context);
    final channel = widget.info.kind == PeerKind.channel;
    final admin = member.role == MemberRole.admin;
    await showMgMenu(
      context,
      position: position,
      items: [
        // A basic group's administrators have no rights to edit.
        if (member.canPromote && !(admin && !widget.rights.isSupergroup))
          MgMenuItem(
            label: admin ? l10n.editAdminRights : l10n.promoteToAdmin,
            icon: MgIcons.star,
            onSelected: () => unawaited(_promote(member)),
          ),
        if (member.canPromote && admin)
          MgMenuItem(
            label: l10n.dismissAdmin,
            icon: MgIcons.close,
            onSelected: () => unawaited(
              _act(() => _management.demote(widget.info.chatId, member.userId)),
            ),
          ),
        if (member.canRestrict)
          MgMenuItem(
            label: l10n.restrictMember,
            icon: MgIcons.lock,
            onSelected: () => unawaited(_restrict(member)),
          ),
        if (member.canRestrict && member.permissions != null)
          MgMenuItem(
            label: l10n.removeRestrictions,
            icon: MgIcons.lockOpen,
            onSelected: () => unawaited(
              _act(() => _management.demote(widget.info.chatId, member.userId)),
            ),
          ),
        if (member.canRemove)
          MgMenuItem(
            label: channel ? l10n.removeFromChannel : l10n.removeFromGroup,
            icon: MgIcons.leave,
            destructive: true,
            onSelected: () => unawaited(_remove(member)),
          ),
      ],
    );
  }

  Future<void> _promote(ManagedMember member) async {
    final chatId = widget.info.chatId;
    final rights = widget.rights;
    // Administrators of a basic group all have the same rights; picking
    // some would make it a supergroup, so it is promote or dismiss.
    if (!rights.isSupergroup) {
      if (member.role == MemberRole.admin) return;
      await _act(
        () => _management.promote(chatId, member.userId, basicGroupAdmin),
      );
      return;
    }
    final choice = await showManageSheet<AdminChoice>(
      context,
      AdminRightsSheet(
        name: member.name,
        channel: widget.info.kind == PeerKind.channel,
        forum: rights.isForum,
        current: member.adminRights,
        granter: rights.isOwner ? null : rights.adminRights,
        title: member.tag,
      ),
    );
    switch (choice) {
      case SaveAdmin(:final rights, :final title):
        await _act(() async {
          await _management.promote(chatId, member.userId, rights);
          if (title != member.tag) {
            await _management.setAdminTitle(chatId, member.userId, title);
          }
        });
      case DismissAdmin():
        await _act(() => _management.demote(chatId, member.userId));
      case null:
        break;
    }
  }

  Future<void> _restrict(ManagedMember member) async {
    final permissions = await showManageSheet<td.ChatPermissions>(
      context,
      RestrictSheet(name: member.name, current: member.permissions),
    );
    if (permissions == null) return;
    await _act(
      () =>
          _management.restrict(widget.info.chatId, member.userId, permissions),
    );
  }

  Future<void> _remove(ManagedMember member) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.removeMemberTitle(member.name),
      confirmLabel: l10n.remove,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null) return;
    await _act(() => _management.remove(widget.info.chatId, member.userId));
  }

  /// Runs a change; the list reloads when TDLib confirms it, and says
  /// so when TDLib refuses.
  Future<void> _act(Future<void> Function() change) async {
    final l10n = AppLocalizations.of(context);
    try {
      await change();
    } on Object {
      if (mounted) setState(() => _error = l10n.memberChangeFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final info = widget.info;
    final now = widget.now;
    final channel = info.kind == PeerKind.channel;
    final searching = _search.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            channel
                ? l10n.subscribersCount(info.memberCount)
                : l10n.membersCount(info.memberCount),
            style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
          ),
        ),
        if (info.memberCount > 10 || searching) ...[
          MgSearchField(
            controller: _search,
            hintText: l10n.searchMembers,
            onChanged: _onQuery,
          ),
          const SizedBox(height: 8),
        ],
        if (widget.rights.canInviteUsers && !info.isDeleted) ...[
          _Group(
            children: [
              _ActionRow(
                label: channel ? l10n.addSubscribers : l10n.addMembers,
                color: c.accent,
                onTap: () => unawaited(
                  showManageSheet<void>(
                    context,
                    AddMembersSheet(chatId: info.chatId, channel: channel),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (_members.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error ?? l10n.nothingFound,
              textAlign: TextAlign.center,
              style: mgTextStyle(c, color: c.fg2),
            ),
          )
        else if (_members.isNotEmpty)
          _Group(
            inset: 52,
            children: [
              for (final member in _members)
                _MemberRow(
                  member: PeerMember(
                    userId: member.userId,
                    name: member.name,
                    status: member.status,
                    photo: member.photo,
                    role: member.role,
                    isBot: member.isBot,
                  ),
                  status: member.isBot
                      ? l10n.statusBot
                      : describeUserStatus(l10n, member.status, now: now),
                  online: isOnline(member.status, now),
                  tag: member.tag,
                  onTap: () => widget.onMember(member.userId),
                  onMenu:
                      member.canPromote ||
                          member.canRestrict ||
                          member.canRemove
                      ? (position) => unawaited(_menu(member, position))
                      : null,
                ),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    error,
                    style: mgTextStyle(c, size: MgType.small, color: c.fg2),
                  ),
                ),
              if (_hasMore)
                _ActionRow(
                  label: l10n.showMoreMembers,
                  color: c.accent,
                  onTap: () {
                    if (!_loading) unawaited(_load(more: true));
                  },
                ),
            ],
          ),
      ],
    );
  }
}
