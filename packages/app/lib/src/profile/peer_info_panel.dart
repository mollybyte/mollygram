import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../chat/formatted_text.dart';
import '../chat/forward_picker.dart';
import '../chat/media_viewer.dart';
import '../chat/message_tile.dart' show SenderAvatar;
import '../chat/report.dart';
import '../secret/secret_chat.dart';
import '../session/providers.dart';
import '../window_drag_area.dart';
import 'add_members_sheet.dart';
import 'admin_log_sheet.dart';
import 'chat_type_sheet.dart';
import 'discussion_sheet.dart';
import 'edit_chat_sheet.dart';
import 'invite_links_sheet.dart';
import 'join_requests_sheet.dart';
import 'last_seen.dart';
import 'manage_sheet.dart';
import 'member_sheets.dart';
import 'peer_info_state.dart';
import 'permissions_sheet.dart';
import 'reactions_sheet.dart';
import 'removed_users_sheet.dart';

part 'management_section.dart';
part 'members_section.dart';

/// The content of the info panel for one chat: the photo, name and
/// status, quick actions, the details in grouped rows and, for a group,
/// its members.
class PeerInfoPanel extends ConsumerWidget {
  const PeerInfoPanel({
    super.key,
    required this.chatId,
    required this.onClose,
    required this.onMember,
    required this.onMessage,
    this.onBack,
    this.onSharedMedia,
  });

  final int chatId;
  final VoidCallback onClose;

  /// Opens the chat's shared media; without it the row isn't shown.
  final VoidCallback? onSharedMedia;

  /// Shown as a back button when the panel came here from a member list.
  final VoidCallback? onBack;
  final ValueChanged<int> onMember;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final info = ref.watch(peerInfoProvider(chatId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(title: l10n.peerInfo, onBack: onBack, onClose: onClose),
        Expanded(
          child: switch (info) {
            AsyncValue(value: final info?) => _MinuteTicker(
              builder: (now) => _Content(
                info: info,
                now: now,
                onMember: onMember,
                onMessage: onMessage,
                onSharedMedia: onSharedMedia,
                onClose: onClose,
              ),
            ),
            AsyncError() => Center(
              child: Text(l10n.infoFailed, style: mgTextStyle(c, color: c.fg2)),
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}

/// A page the info panel goes on to, such as the shared media: [title]
/// over [child], with a back button to the info.
class PeerInfoPage extends StatelessWidget {
  const PeerInfoPage({
    super.key,
    required this.title,
    required this.onBack,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _TopBar(title: title, onBack: onBack, onClose: onClose),
      Expanded(child: child),
    ],
  );
}

/// Opens the profile's photos in the viewer, newest first; nothing
/// happens when there are none to show.
Future<void> _openPhotos(
  BuildContext context,
  WidgetRef ref,
  PeerInfo info,
) async {
  final session = ref.read(telegramSessionProvider).asData?.value;
  if (session == null) return;
  final List<ProfilePhoto> photos;
  try {
    photos = await session.conversations.profilePhotos(
      info.chatId,
      userId: info.userId,
    );
  } on td.TdException {
    return;
  }
  if (photos.isEmpty || !context.mounted) return;
  await showProfilePhotos(context, photos: photos, title: info.title);
}

/// The big photo at the top; a click opens the profile's photos, as the
/// official app does, so the pointer turns into a hand over it.
class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({
    required this.name,
    required this.photo,
    required this.onTap,
  });

  final String name;
  final td.File? photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = SenderAvatar(name: name, size: 88, photo: photo);
    final onTap = this.onTap;
    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      label: name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: avatar),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onClose, this.onBack});

  final String title;
  final VoidCallback onClose;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          const Positioned.fill(child: WindowDragArea()),
          Positioned(
            left: 12,
            right: 12,
            top: 16,
            height: 32,
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: onBack == null
                      ? null
                      : MgIconButton(
                          icon: MgIcons.back,
                          tooltip: l10n.back,
                          onPressed: onBack,
                        ),
                ),
                Expanded(
                  child: IgnorePointer(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: mgTextStyle(
                        c,
                        size: MgType.title,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                MgIconButton(
                  icon: MgIcons.close,
                  tooltip: l10n.close,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rebuilds at every new minute, so "last seen 5 minutes ago" and
/// "online" stay true while the panel is open.
class _MinuteTicker extends StatefulWidget {
  const _MinuteTicker({required this.builder});

  final Widget Function(DateTime now) builder;

  @override
  State<_MinuteTicker> createState() => _MinuteTickerState();
}

class _MinuteTickerState extends State<_MinuteTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    _timer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(DateTime.now());
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.now,
    required this.info,
    required this.onMember,
    required this.onMessage,
    required this.onSharedMedia,
    required this.onClose,
  });

  final PeerInfo info;
  final DateTime now;
  final ValueChanged<int> onMember;
  final VoidCallback onMessage;
  final VoidCallback? onSharedMedia;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final peers = ref.read(telegramSessionProvider).requireValue.peers;
    final rights = info.isUser
        ? ChatRights.none
        : ref.watch(chatRightsProvider(info.chatId)).value ?? ChatRights.none;
    final channel = info.kind == PeerKind.channel;
    final title = info.isDeleted ? l10n.deletedAccount : info.title;
    final status = describePeerStatus(l10n, info, now: now);

    // A bot's commands in its own info go to the chat with it.
    final commandChat = info.kind == PeerKind.bot ? info.chatId : null;
    final details = <Widget>[
      if (info.bio case final bio? when bio.text.isNotEmpty)
        _InfoRow(
          label: l10n.infoBio,
          child: FormattedTextView(
            text: bio,
            style: mgTextStyle(c),
            chatId: commandChat,
          ),
        ),
      if (info.description case final description?)
        _InfoRow(
          label: l10n.infoDescription,
          child: FormattedTextView(
            text: description,
            style: mgTextStyle(c),
            chatId: commandChat,
          ),
        ),
      if (info.isUser && info.usernames.isNotEmpty)
        _InfoRow(
          label: l10n.infoUsername,
          value: '@${info.usernames.first}',
          copy: '@${info.usernames.first}',
        ),
      if (info.formattedPhone.isNotEmpty)
        _InfoRow(
          label: l10n.infoPhone,
          value: info.formattedPhone,
          copy: '+${info.phone}',
        ),
      if (info.birthdate case final birthdate?)
        _InfoRow(
          label: l10n.infoBirthday,
          value: describeBirthdate(l10n, birthdate),
        ),
      if (info.inviteLink.isNotEmpty)
        _InfoRow(
          label: l10n.infoLink,
          value: info.inviteLink.replaceFirst('https://', ''),
          copy: info.inviteLink,
        ),
    ];

    final canAct = !info.isDeleted;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _ProfilePhoto(
              name: title,
              photo: info.photo,
              onTap: info.photo == null
                  ? null
                  : () => unawaited(_openPhotos(context, ref, info)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            style: mgTextStyle(
              c,
              size: 17,
              weight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              status,
              textAlign: TextAlign.center,
              style: mgTextStyle(
                c,
                size: MgType.small,
                color: isOnline(info.status, now) ? c.accent : c.fg2,
              ),
            ),
          ],
          if (canAct) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (info.isUser) ...[
                  _ActionTile(
                    icon: MgIcons.chat,
                    label: l10n.infoMessage,
                    onTap: onMessage,
                  ),
                  if (!info.isSelf) const SizedBox(width: 8),
                ],
                if (!info.isSelf)
                  _ActionTile(
                    icon: MgIcons.notifications,
                    label: info.isMuted ? l10n.infoUnmute : l10n.infoMute,
                    onTap: info.isMuted
                        ? () => unawaited(
                            peers
                                .setMuted(info.chatId, muted: false)
                                .catchError((Object _) {}),
                          )
                        : null,
                    onMenu: info.isMuted
                        ? null
                        : (position) => unawaited(
                            _muteMenu(context, position, peers, info.chatId),
                          ),
                  ),
                if (rights.canChangeInfo) ...[
                  const SizedBox(width: 8),
                  _ActionTile(
                    icon: MgIcons.compose,
                    label: l10n.edit,
                    onTap: () => unawaited(
                      showManageSheet<void>(context, EditChatSheet(info: info)),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Group(children: details),
          ],
          if (onSharedMedia case final onSharedMedia? when !info.isDeleted) ...[
            const SizedBox(height: 12),
            _Group(
              children: [
                _NavRow(label: l10n.sharedMedia, onTap: onSharedMedia),
              ],
            ),
          ],
          if (canAct &&
              !info.isSelf &&
              (info.kind == PeerKind.user || rights.canChangeInfo)) ...[
            const SizedBox(height: 12),
            _Group(
              children: [
                _NavRow(
                  label: l10n.autoDeleteTitle,
                  value: _autoDeleteLabel(l10n, info.autoDeleteTime),
                  onTap: () => unawaited(_autoDeleteMenu(context, peers, info)),
                ),
              ],
            ),
          ],
          if (canAct && info.kind == PeerKind.user && !info.isSelf) ...[
            const SizedBox(height: 12),
            _Group(
              children: [
                _NavRow(
                  label: secretChatActionLabel(info.chatId, l10n),
                  onTap: () => unawaited(
                    runSecretChatAction(
                      context,
                      chatId: info.chatId,
                      userId: info.userId,
                      name: info.title,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Group(
              children: [
                if (info.phone.isNotEmpty)
                  _NavRow(
                    label: l10n.infoShareContact,
                    onTap: () => unawaited(_shareContact(context, ref)),
                  ),
                _ActionRow(
                  label: info.isBlocked ? l10n.unblockUser : l10n.blockUser,
                  color: info.isBlocked ? c.accent : MgDestructive.color,
                  onTap: () => unawaited(_toggleBlock(context, peers)),
                ),
                _ActionRow(
                  label: l10n.menuReport,
                  color: MgDestructive.color,
                  onTap: () => unawaited(_report(context, ref)),
                ),
              ],
            ),
          ],
          if (canAct && !info.isUser) ...[
            const SizedBox(height: 12),
            _Group(
              children: [
                _ActionRow(
                  label: l10n.menuReport,
                  color: MgDestructive.color,
                  onTap: () => unawaited(_report(context, ref)),
                ),
              ],
            ),
          ],
          if (!info.isUser && (rights.isOwner || rights.isAdmin)) ...[
            const SizedBox(height: 12),
            _ManagementSection(info: info, rights: rights),
          ],
          // Channel subscribers are for its administrators to see.
          if (channel
              ? rights.isOwner || rights.isAdmin
              : info.members.isNotEmpty)
            _MembersSection(
              key: ValueKey(info.chatId),
              info: info,
              rights: rights,
              now: now,
              onMember: onMember,
            ),
          if (!info.isUser && rights.isMember) ...[
            const SizedBox(height: 16),
            _LeaveRows(info: info, rights: rights, onLeft: onClose),
          ],
        ],
      ),
    );
  }

  /// Sends the person as a contact card to a chat the user picks.
  Future<void> _shareContact(BuildContext context, WidgetRef ref) async {
    final target = await pickForwardTarget(context);
    if (target == null || !context.mounted) return;
    final session = ref.read(telegramSessionProvider).asData?.value;
    if (session == null) return;
    try {
      await session.conversations.sendContact(
        target.chatId,
        td.Contact(
          phoneNumber: info.phone,
          firstName: info.firstName,
          lastName: info.lastName,
          vcard: '',
          userId: info.userId,
        ),
      );
    } on td.TdException {
      if (context.mounted) {
        showMgToast(context, AppLocalizations.of(context).sendFailed);
      }
    }
  }

  /// Reports the chat: the server's reasons, then details when asked.
  Future<void> _report(BuildContext context, WidgetRef ref) {
    final session = ref.read(telegramSessionProvider).asData?.value;
    if (session == null) return Future.value();
    return reportMessages(
      context,
      conversations: session.conversations,
      chatId: info.chatId,
      messageIds: const [],
      isShown: () => context.mounted,
    );
  }

  Future<void> _toggleBlock(
    BuildContext context,
    PeerInfoController peers,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (!info.isBlocked) {
      final confirmed = await showMgConfirm(
        context,
        title: l10n.blockConfirmTitle(info.title),
        message: l10n.blockConfirmMessage,
        confirmLabel: l10n.block,
        cancelLabel: l10n.cancel,
        destructive: true,
      );
      if (confirmed == null) return;
    }
    await peers
        .setBlocked(info.chatId, blocked: !info.isBlocked)
        .catchError((Object _) {});
  }
}

/// A rounded card of rows with hairlines between them, like a group in
/// macOS System Settings.
class _Group extends StatelessWidget {
  const _Group({required this.children, this.inset = 12});

  final List<Widget> children;

  /// Where the hairlines start: under the text, past any avatar.
  final double inset;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: c.field,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsets.only(left: inset),
                  child: SizedBox(
                    height: 1,
                    child: ColoredBox(color: c.separator),
                  ),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A row that highlights under the pointer and reacts to clicks.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.onTap, this.onMenu});

  final Widget child;
  final VoidCallback? onTap;

  /// A right click, with where it happened, for a context menu.
  final ValueChanged<Offset>? onMenu;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: enabled ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onSecondaryTapUp: widget.onMenu == null
            ? null
            : (details) => widget.onMenu!(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hover && enabled ? c.hover : const Color(0x00000000),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A detail with its label above it. With [copy] set, a click copies it
/// and the label says so for a moment.
class _InfoRow extends StatefulWidget {
  const _InfoRow({required this.label, this.value, this.child, this.copy});

  final String label;
  final String? value;

  /// Shown instead of [value], for text with links.
  final Widget? child;
  final String? copy;

  @override
  State<_InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<_InfoRow> {
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    unawaited(Clipboard.setData(ClipboardData(text: widget.copy!)));
    _copiedTimer?.cancel();
    setState(() {
      _copiedTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _copiedTimer = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final copied = _copiedTimer != null;
    return _Pressable(
      onTap: widget.copy == null ? null : _copy,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                copied ? AppLocalizations.of(context).copied : widget.label,
                key: ValueKey(copied),
                style: mgTextStyle(
                  c,
                  size: MgType.caption,
                  color: copied ? c.accent : c.fg2,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 2),
            widget.child ?? Text(widget.value ?? '', style: mgTextStyle(c)),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return _Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(label, style: mgTextStyle(c, color: color)),
      ),
    );
  }
}

/// A row that leads to another page of the panel, with what is there
/// now in grey before the chevron, like a System Settings row.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap, this.value});

  final String label;

  /// The current setting, muted, before the chevron.
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      child: _Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Expanded(child: Text(label, style: mgTextStyle(c))),
              if (value case final value?) ...[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(c, color: c.fg2),
                ),
                const SizedBox(width: 4),
              ],
              MgIcon(MgIcons.chevron, size: 14, color: c.fg2),
            ],
          ),
        ),
      ),
    );
  }
}

/// The mute tile's menu: for an hour, eight hours, two days, or until
/// the user turns notifications back on.
Future<void> _muteMenu(
  BuildContext context,
  Offset position,
  PeerInfoController peers,
  int chatId,
) {
  final l10n = AppLocalizations.of(context);
  MgMenuItem item(String label, int seconds) => MgMenuItem(
    label: label,
    onSelected: () =>
        unawaited(peers.setMuteFor(chatId, seconds).catchError((Object _) {})),
  );
  return showMgMenu(
    context,
    position: position,
    items: [
      item(l10n.muteForHours(1), 3600),
      item(l10n.muteForHours(8), 8 * 3600),
      item(l10n.muteForDays(2), 2 * 86400),
      item(l10n.muteUntilEnabled, PeerInfoController.muteForever),
    ],
  );
}

/// The auto-delete row's menu: off, a day, a week or a month, as the
/// official app offers.
Future<void> _autoDeleteMenu(
  BuildContext context,
  PeerInfoController peers,
  PeerInfo info,
) {
  final l10n = AppLocalizations.of(context);
  final box = context.findRenderObject()! as RenderBox;
  MgMenuItem item(int seconds) => MgMenuItem(
    label: _autoDeleteLabel(l10n, seconds),
    onSelected: () => unawaited(
      peers.setAutoDeleteTime(info.chatId, seconds).catchError((Object _) {}),
    ),
  );
  return showMgMenu(
    context,
    position: box.localToGlobal(Offset(box.size.width - 220, 0)),
    items: [item(0), item(86400), item(7 * 86400), item(31 * 86400)],
  );
}

String _autoDeleteLabel(AppLocalizations l10n, int seconds) =>
    switch (seconds) {
      0 => l10n.selfDestructOff,
      86400 => l10n.oneDay,
      604800 => l10n.oneWeek,
      2678400 => l10n.oneMonth,
      _ when seconds >= 604800 => l10n.ttlDays(seconds ~/ 86400),
      _ when seconds >= 86400 => l10n.selfDestructDays(seconds ~/ 86400),
      _ when seconds >= 3600 => l10n.selfDestructHours(seconds ~/ 3600),
      _ => l10n.selfDestructMinutes(seconds ~/ 60),
    };

/// A quick action under the name: an icon over a short label.
class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.onMenu,
  }) : assert(onTap != null || onMenu != null, 'a tile does something');

  final MgIconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Opens a menu under the tile, at the position given.
  final void Function(Offset position)? onMenu;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () {
            final menu = widget.onMenu;
            if (menu == null) return widget.onTap?.call();
            final box = context.findRenderObject()! as RenderBox;
            menu(box.localToGlobal(Offset(0, box.size.height + 4)));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 88,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                _hover ? c.hover : const Color(0x00000000),
                c.field,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MgIcon(widget.icon, size: 18, color: c.accent),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(
                    c,
                    size: MgType.caption,
                    color: c.accent,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.status,
    required this.online,
    required this.onTap,
    this.onMenu,
    this.tag = '',
  });

  final PeerMember member;
  final String status;
  final bool online;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onMenu;

  /// An administrator's own title, in place of "admin".
  final String tag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final role = switch (member.role) {
      MemberRole.owner => tag.isNotEmpty ? tag : l10n.memberOwner,
      MemberRole.admin => tag.isNotEmpty ? tag : l10n.memberAdmin,
      MemberRole.member => '',
    };
    return _Pressable(
      onTap: onTap,
      onMenu: onMenu,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            SenderAvatar(name: member.name, size: 32, photo: member.photo),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name.isEmpty ? l10n.deletedAccount : member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(c, weight: FontWeight.w500, height: 1.3),
                  ),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(
                      c,
                      size: MgType.caption,
                      color: online ? c.accent : c.fg2,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (role.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                role,
                style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Leave, and for the owner Delete, with a confirmation. A refusal from
/// TDLib is said under the rows.
class _LeaveRows extends ConsumerStatefulWidget {
  const _LeaveRows({
    required this.info,
    required this.rights,
    required this.onLeft,
  });

  final PeerInfo info;
  final ChatRights rights;
  final VoidCallback onLeft;

  @override
  ConsumerState<_LeaveRows> createState() => _LeaveRowsState();
}

class _LeaveRowsState extends ConsumerState<_LeaveRows> {
  String? _error;

  Future<void> _leave({required bool delete}) async {
    final l10n = AppLocalizations.of(context);
    final channel = widget.info.kind == PeerKind.channel;
    // The owner of a supergroup or channel stays its owner after leaving
    // and may come back; say so before they go.
    final ownerNote = widget.rights.isOwner && widget.rights.isSupergroup
        ? l10n.leaveOwnerNote
        : null;
    final confirmed = await showMgConfirm(
      context,
      title: delete
          ? (channel ? l10n.deleteChannelTitle : l10n.deleteGroupTitle)
          : (channel ? l10n.leaveChannelTitle : l10n.leaveGroupTitle),
      message: delete
          ? (channel ? l10n.deleteChannelMessage : l10n.deleteGroupMessage)
          : ownerNote,
      confirmLabel: delete ? l10n.deleteForEveryone : l10n.leave,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null || !mounted) return;
    final management = ref
        .read(telegramSessionProvider)
        .requireValue
        .management;
    try {
      delete
          ? await management.deleteChat(widget.info.chatId)
          : await management.leave(widget.info.chatId);
      widget.onLeft();
    } on Object {
      if (mounted) {
        setState(() => _error = delete ? l10n.deleteFailed : l10n.leaveFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final channel = widget.info.kind == PeerKind.channel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          children: [
            _ActionRow(
              label: channel ? l10n.leaveChannel : l10n.leaveGroup,
              color: MgDestructive.color,
              onTap: () => unawaited(_leave(delete: false)),
            ),
            if (widget.rights.canDeleteChat)
              _ActionRow(
                label: channel ? l10n.deleteChannel : l10n.deleteGroup,
                color: MgDestructive.color,
                onTap: () => unawaited(_leave(delete: true)),
              ),
          ],
        ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              error,
              style: mgTextStyle(c, size: MgType.small, color: c.fg2),
            ),
          ),
      ],
    );
  }
}
