import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'manage_sheet.dart';

/// What the user chose in [AdminRightsSheet].
sealed class AdminChoice {
  const AdminChoice();
}

/// Appoint, or keep as an administrator, with [rights] and a [title]
/// shown in place of "admin" (empty for the usual one).
final class SaveAdmin extends AdminChoice {
  const SaveAdmin(this.rights, {this.title = ''});

  final td.ChatAdministratorRights rights;
  final String title;
}

/// Make a plain member again.
final class DismissAdmin extends AdminChoice {
  const DismissAdmin();
}

/// The rights a sheet shows, in TelegramSwift's order.
enum AdminRight {
  changeInfo,
  postMessages,
  editMessages,
  deleteMessages,
  restrictMembers,
  inviteUsers,
  pinMessages,
  manageTopics,
  manageVideoChats,
  promoteMembers,
  anonymous;

  /// The rights that mean something in a group, or in a channel.
  static List<AdminRight> of({required bool channel, bool forum = false}) =>
      channel
      ? const [
          changeInfo,
          postMessages,
          editMessages,
          deleteMessages,
          inviteUsers,
          manageVideoChats,
          promoteMembers,
        ]
      : [
          changeInfo,
          deleteMessages,
          restrictMembers,
          inviteUsers,
          pinMessages,
          if (forum) manageTopics,
          manageVideoChats,
          promoteMembers,
          anonymous,
        ];

  String label(
    AppLocalizations l10n, {
    required bool channel,
  }) => switch (this) {
    changeInfo => channel ? l10n.rightChangeChannelInfo : l10n.rightChangeInfo,
    postMessages => l10n.rightPostMessages,
    editMessages => l10n.rightEditMessages,
    deleteMessages => l10n.rightDeleteMessages,
    restrictMembers => l10n.rightBanUsers,
    inviteUsers => channel ? l10n.rightAddSubscribers : l10n.rightInviteUsers,
    pinMessages => l10n.rightPinMessages,
    manageTopics => l10n.rightManageTopics,
    manageVideoChats => l10n.rightManageVideoChats,
    promoteMembers => l10n.rightAddAdmins,
    anonymous => l10n.rightAnonymous,
  };
}

/// The rights of [rights] as a set.
Set<AdminRight> rightsOf(td.ChatAdministratorRights rights) => {
  if (rights.canChangeInfo) AdminRight.changeInfo,
  if (rights.canPostMessages) AdminRight.postMessages,
  if (rights.canEditMessages) AdminRight.editMessages,
  if (rights.canDeleteMessages) AdminRight.deleteMessages,
  if (rights.canRestrictMembers) AdminRight.restrictMembers,
  if (rights.canInviteUsers) AdminRight.inviteUsers,
  if (rights.canPinMessages) AdminRight.pinMessages,
  if (rights.canManageTopics) AdminRight.manageTopics,
  if (rights.canManageVideoChats) AdminRight.manageVideoChats,
  if (rights.canPromoteMembers) AdminRight.promoteMembers,
  if (rights.isAnonymous) AdminRight.anonymous,
};

/// [base] with the [shown] rights set as [on] says; rights a sheet does
/// not show keep their value. A new administrator ([base] null) gets the
/// story rights with posting, editing and deleting, as in the official
/// apps.
td.ChatAdministratorRights adminRights(
  Set<AdminRight> on, {
  td.ChatAdministratorRights? base,
  Iterable<AdminRight> shown = AdminRight.values,
}) {
  final visible = shown.toSet();
  bool pick(AdminRight right, bool? current) =>
      visible.contains(right) ? on.contains(right) : current ?? false;
  return td.ChatAdministratorRights(
    canManageChat: true,
    canChangeInfo: pick(AdminRight.changeInfo, base?.canChangeInfo),
    canPostMessages: pick(AdminRight.postMessages, base?.canPostMessages),
    canEditMessages: pick(AdminRight.editMessages, base?.canEditMessages),
    canDeleteMessages: pick(AdminRight.deleteMessages, base?.canDeleteMessages),
    canInviteUsers: pick(AdminRight.inviteUsers, base?.canInviteUsers),
    canRestrictMembers: pick(
      AdminRight.restrictMembers,
      base?.canRestrictMembers,
    ),
    canPinMessages: pick(AdminRight.pinMessages, base?.canPinMessages),
    canManageTopics: pick(AdminRight.manageTopics, base?.canManageTopics),
    canPromoteMembers: pick(AdminRight.promoteMembers, base?.canPromoteMembers),
    canManageVideoChats: pick(
      AdminRight.manageVideoChats,
      base?.canManageVideoChats,
    ),
    canPostStories:
        base?.canPostStories ?? on.contains(AdminRight.postMessages),
    canEditStories:
        base?.canEditStories ?? on.contains(AdminRight.editMessages),
    canDeleteStories:
        base?.canDeleteStories ?? on.contains(AdminRight.deleteMessages),
    canManageDirectMessages: base?.canManageDirectMessages ?? false,
    canManageTags: base?.canManageTags ?? false,
    canSendWelcomeMessages: base?.canSendWelcomeMessages ?? false,
    isAnonymous: pick(AdminRight.anonymous, base?.isAnonymous),
  );
}

/// The rights every administrator of a basic group has.
final basicGroupAdmin = adminRights({
  AdminRight.changeInfo,
  AdminRight.deleteMessages,
  AdminRight.restrictMembers,
  AdminRight.inviteUsers,
  AdminRight.pinMessages,
  AdminRight.manageVideoChats,
});

/// Appoints an administrator or edits one: a switch for each right, and
/// for an administrator already there, a way to dismiss them.
class AdminRightsSheet extends StatefulWidget {
  const AdminRightsSheet({
    super.key,
    required this.name,
    required this.channel,
    this.forum = false,
    this.current,
    this.granter,
    this.title = '',
  });

  final String name;
  final bool channel;
  final bool forum;

  /// The administrator's title so far.
  final String title;

  /// The rights of the administrator appointing, who can only give what
  /// they have; null for the owner.
  final td.ChatAdministratorRights? granter;

  /// The rights of an administrator being edited; null to appoint one.
  final td.ChatAdministratorRights? current;

  @override
  State<AdminRightsSheet> createState() => _AdminRightsSheetState();
}

class _AdminRightsSheetState extends State<AdminRightsSheet> {
  // A new administrator gets everything but adding others and hiding,
  // as in TelegramSwift.
  late final _shown = AdminRight.of(
    channel: widget.channel,
    forum: widget.forum,
  );
  late final _on = widget.current == null
      ? {
          for (final right in _shown)
            if (right != AdminRight.promoteMembers &&
                right != AdminRight.anonymous &&
                _mayGive(right))
              right,
        }
      : rightsOf(widget.current!);

  late final _title = TextEditingController(text: widget.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool _mayGive(AdminRight right) =>
      widget.granter == null || rightsOf(widget.granter!).contains(right);

  void _save() => Navigator.of(context).pop(
    SaveAdmin(
      adminRights(_on, base: widget.current, shown: _shown),
      title: _title.text.trim(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    return ManageSheetFrame(
      title: widget.current == null ? l10n.addAdmin : l10n.adminRights,
      action: l10n.save,
      onAction: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: MgUnderlineField(
              controller: _title,
              hintText: l10n.adminTitleHint,
              fontSize: 14,
              onSubmitted: (_) => _save(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Text(
              l10n.adminTitleNote,
              style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
            ),
          ),
          SheetCaption(l10n.adminRightsOf(widget.name)),
          for (final right in _shown)
            ToggleRow(
              label: right.label(l10n, channel: widget.channel),
              value: _on.contains(right),
              // Rights the user doesn't hold can't be given or taken.
              onChanged: _mayGive(right)
                  ? (on) =>
                        setState(() => on ? _on.add(right) : _on.remove(right))
                  : null,
            ),
          if (widget.current != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: _DestructiveLink(
                label: l10n.dismissAdmin,
                onTap: () => Navigator.of(context).pop(const DismissAdmin()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What a restricted member may still do, grouped as the official apps
/// show it.
enum MemberPermission {
  sendMessages,
  sendMedia,
  sendStickers,
  sendPolls,
  embedLinks,
  inviteUsers,
  pinMessages,
  changeInfo,
  createTopics;

  /// The permissions that mean something in a group; topics only in a
  /// forum.
  static List<MemberPermission> of({bool forum = false}) => [
    for (final permission in values)
      if (permission != createTopics || forum) permission,
  ];

  String label(AppLocalizations l10n) => switch (this) {
    sendMessages => l10n.permSendMessages,
    sendMedia => l10n.permSendMedia,
    sendStickers => l10n.permSendStickers,
    sendPolls => l10n.permSendPolls,
    embedLinks => l10n.permEmbedLinks,
    inviteUsers => l10n.rightInviteUsers,
    pinMessages => l10n.rightPinMessages,
    changeInfo => l10n.rightChangeInfo,
    createTopics => l10n.permCreateTopics,
  };
}

/// The permissions of [p] as a set.
Set<MemberPermission> permissionsOf(td.ChatPermissions p) => {
  if (p.canSendBasicMessages) MemberPermission.sendMessages,
  if (p.canSendPhotos && p.canSendVideos) MemberPermission.sendMedia,
  if (p.canSendOtherMessages) MemberPermission.sendStickers,
  if (p.canSendPolls) MemberPermission.sendPolls,
  if (p.canAddLinkPreviews) MemberPermission.embedLinks,
  if (p.canInviteUsers) MemberPermission.inviteUsers,
  if (p.canPinMessages) MemberPermission.pinMessages,
  if (p.canChangeInfo) MemberPermission.changeInfo,
  if (p.canCreateTopics) MemberPermission.createTopics,
};

/// TDLib permissions with [on] given.
td.ChatPermissions memberPermissions(Set<MemberPermission> on) {
  final media = on.contains(MemberPermission.sendMedia);
  return td.ChatPermissions(
    canSendBasicMessages: on.contains(MemberPermission.sendMessages),
    canSendAudios: media,
    canSendDocuments: media,
    canSendPhotos: media,
    canSendVideos: media,
    canSendVideoNotes: media,
    canSendVoiceNotes: media,
    canSendPolls: on.contains(MemberPermission.sendPolls),
    canSendOtherMessages: on.contains(MemberPermission.sendStickers),
    canAddLinkPreviews: on.contains(MemberPermission.embedLinks),
    canReactToMessages: true,
    canEditTag: false,
    canChangeInfo: on.contains(MemberPermission.changeInfo),
    canInviteUsers: on.contains(MemberPermission.inviteUsers),
    canPinMessages: on.contains(MemberPermission.pinMessages),
    canCreateTopics: on.contains(MemberPermission.createTopics),
  );
}

/// Limits what one member may do. Completes with the permissions left to
/// them, or null when cancelled.
class RestrictSheet extends StatefulWidget {
  const RestrictSheet({super.key, required this.name, this.current});

  final String name;

  /// The permissions of a member already restricted.
  final td.ChatPermissions? current;

  @override
  State<RestrictSheet> createState() => _RestrictSheetState();
}

class _RestrictSheetState extends State<RestrictSheet> {
  // Restricting starts from read-only, the usual reason to restrict.
  late final _on = widget.current == null
      ? <MemberPermission>{}
      : permissionsOf(widget.current!);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ManageSheetFrame(
      title: l10n.restrictMember,
      action: l10n.save,
      onAction: () => Navigator.of(context).pop(memberPermissions(_on)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetCaption(l10n.restrictWhatCan(widget.name)),
          for (final permission in MemberPermission.of())
            ToggleRow(
              label: permission.label(l10n),
              value: _on.contains(permission),
              onChanged: (on) => setState(
                () => on ? _on.add(permission) : _on.remove(permission),
              ),
            ),
        ],
      ),
    );
  }
}

class _DestructiveLink extends StatelessWidget {
  const _DestructiveLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              label,
              style: mgTextStyle(c, color: MgDestructive.color),
            ),
          ),
        ),
      ),
    );
  }
}
