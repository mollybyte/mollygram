import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../avatar/peer_avatar.dart';
import '../chat/message_tile.dart' show SenderAvatar;
import '../session/providers.dart';
import 'manage_sheet.dart';

/// A channel's discussion group: the one linked now with a way to
/// unlink it, or the user's groups to pick one from. From a group, the
/// channel it is linked to.
class DiscussionSheet extends ConsumerStatefulWidget {
  const DiscussionSheet({super.key, required this.settings});

  final ChatSettings settings;

  @override
  ConsumerState<DiscussionSheet> createState() => _DiscussionSheetState();
}

class _DiscussionSheetState extends ConsumerState<DiscussionSheet> {
  late final ChatManagement _management = ref
      .read(telegramSessionProvider)
      .requireValue
      .management;
  List<(int, String)>? _groups;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.settings.isChannel && widget.settings.linkedChatId == 0) {
      unawaited(_loadGroups());
    }
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _management.suitableDiscussionGroups();
      if (mounted) setState(() => _groups = groups);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _link(int? groupId) async {
    final settings = widget.settings;
    try {
      await _management.setDiscussionGroup(
        settings.isChannel ? settings.chatId : settings.linkedChatId,
        groupId,
      );
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _unlink() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.unlinkTitle,
      message: widget.settings.isChannel
          ? l10n.unlinkGroupMessage
          : l10n.unlinkChannelMessage,
      confirmLabel: l10n.unlink,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null) return;
    await _link(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final settings = widget.settings;
    final groups = _groups;
    final chatLists = ref.read(telegramSessionProvider).requireValue.chatLists;
    final hasLinked = settings.linkedChatId != 0;
    return ManageSheetFrame(
      title: settings.isChannel ? l10n.discussionGroup : l10n.linkedChannel,
      height: hasLinked ? null : 400,
      error: _failed ? l10n.saveFailed : null,
      child: hasLinked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PersonRow(
                  name: settings.linkedChatTitle,
                  avatar: SenderAvatar(
                    name: settings.linkedChatTitle,
                    size: 30,
                  ),
                  subtitle: settings.isChannel
                      ? l10n.discussionGroupNote
                      : l10n.linkedChannelNote,
                  actions: [(l10n.unlink, () => unawaited(_unlink()))],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    l10n.pickDiscussionGroup,
                    style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: groups == null
                      ? const SizedBox.shrink()
                      : groups.isEmpty
                      ? SheetNotice(l10n.noSuitableGroups)
                      : ListView(
                          children: [
                            for (final (id, title) in groups)
                              PersonRow(
                                name: title,
                                avatar: PeerAvatar.chat(
                                  name: title,
                                  size: 30,
                                  photo: chatLists.store.chat(id)?.photo,
                                ),
                                onTap: () => unawaited(_link(id)),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
