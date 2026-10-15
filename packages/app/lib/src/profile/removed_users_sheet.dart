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
import 'member_sheets.dart';

/// The users banned from a group or channel and the ones restricted in
/// it, with a way to let them back or lift the restriction.
class RemovedUsersSheet extends ConsumerStatefulWidget {
  const RemovedUsersSheet({super.key, required this.chatId, this.now});

  final int chatId;
  final DateTime Function()? now;

  @override
  ConsumerState<RemovedUsersSheet> createState() => _RemovedUsersSheetState();
}

class _RemovedUsersSheetState extends ConsumerState<RemovedUsersSheet> {
  late final ChatManagement _management = ref
      .read(telegramSessionProvider)
      .requireValue
      .management;
  final _search = TextEditingController();
  List<RemovedMember>? _members;
  var _failed = false;
  Timer? _debounce;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final members = await _management.removedMembers(
        widget.chatId,
        query: _search.text.trim(),
      );
      if (mounted && generation == _generation) {
        setState(() {
          _members = members;
          _failed = false;
        });
      }
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
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

  Future<void> _unban(RemovedMember member) async {
    try {
      await _management.unban(
        widget.chatId,
        member.userId,
        banned: member.isBanned,
      );
      if (mounted) {
        setState(() => _members = [...?_members?.where((m) => m != member)]);
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _edit(RemovedMember member) async {
    final permissions = await showManageSheet<td.ChatPermissions>(
      context,
      RestrictSheet(name: member.name, current: member.permissions),
    );
    if (permissions == null || !mounted) return;
    try {
      await _management.restrict(widget.chatId, member.userId, permissions);
      await _load();
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = _members;
    final now = (widget.now ?? DateTime.now)();
    return ManageSheetFrame(
      title: l10n.removedUsers,
      height: 460,
      error: _failed ? l10n.membersFailed : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MgSearchField(
            controller: _search,
            hintText: l10n.searchMembers,
            onChanged: _onQuery,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: members == null
                ? const SizedBox.shrink()
                : members.isEmpty
                ? SheetNotice(
                    _search.text.trim().isEmpty
                        ? l10n.noRemovedUsers
                        : l10n.nothingFound,
                  )
                : ListView(
                    children: [
                      for (final member in members)
                        PersonRow(
                          name: member.name,
                          avatar: SenderAvatar(
                            name: member.name,
                            size: 30,
                            photo: member.photo,
                          ),
                          subtitle: describeRemoved(l10n, member, now),
                          onTap: member.isBanned
                              ? null
                              : () => unawaited(_edit(member)),
                          actions: [
                            (
                              member.isBanned
                                  ? l10n.unban
                                  : l10n.removeRestrictions,
                              () => unawaited(_unban(member)),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Banned", "Banned until Oct 20", "Can't send media · until Oct 20".
String describeRemoved(
  AppLocalizations l10n,
  RemovedMember member,
  DateTime now,
) {
  final until = member.until == null
      ? null
      : l10n.untilDate(DateFormat.MMMd(l10n.localeName).format(member.until!));
  if (member.isBanned) {
    return until == null ? l10n.banned : l10n.bannedUntil(until);
  }
  final left = permissionsOf(member.permissions!);
  final denied = [
    for (final permission in MemberPermission.of())
      if (!left.contains(permission)) permission.label(l10n),
  ];
  final what = denied.isEmpty
      ? l10n.restricted
      : l10n.cannot(denied.take(2).join(', ').toLowerCase());
  return until == null ? what : '$what · $until';
}
