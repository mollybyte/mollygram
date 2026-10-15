import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'manage_sheet.dart';

/// What the user chose in [AdminRightsSheet].
sealed class AdminChoice {
  const AdminChoice();
}

/// Appoint, or keep as an administrator, with [rights].
final class SaveAdmin extends AdminChoice {
  const SaveAdmin(this.rights);

  final td.ChatAdministratorRights rights;
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
  manageVideoChats,
  promoteMembers,
  anonymous;

  /// The rights that mean something in a group, or in a channel.
  static List<AdminRight> of({required bool channel}) => channel
      ? const [
          changeInfo,
          postMessages,
          editMessages,
          deleteMessages,
          inviteUsers,
          manageVideoChats,
          promoteMembers,
        ]
      : const [
          changeInfo,
          deleteMessages,
          restrictMembers,
          inviteUsers,
          pinMessages,
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
  if (rights.canManageVideoChats) AdminRight.manageVideoChats,
  if (rights.canPromoteMembers) AdminRight.promoteMembers,
  if (rights.isAnonymous) AdminRight.anonymous,
};

/// TDLib rights with [on] given. Stories follow posting, as in the
/// official apps; the rest of what a sheet doesn't show stays off.
td.ChatAdministratorRights adminRights(Set<AdminRight> on) =>
    td.ChatAdministratorRights(
      canManageChat: true,
      canChangeInfo: on.contains(AdminRight.changeInfo),
      canPostMessages: on.contains(AdminRight.postMessages),
      canEditMessages: on.contains(AdminRight.editMessages),
      canDeleteMessages: on.contains(AdminRight.deleteMessages),
      canInviteUsers: on.contains(AdminRight.inviteUsers),
      canRestrictMembers: on.contains(AdminRight.restrictMembers),
      canPinMessages: on.contains(AdminRight.pinMessages),
      canManageTopics: false,
      canPromoteMembers: on.contains(AdminRight.promoteMembers),
      canManageVideoChats: on.contains(AdminRight.manageVideoChats),
      canPostStories: on.contains(AdminRight.postMessages),
      canEditStories: on.contains(AdminRight.editMessages),
      canDeleteStories: on.contains(AdminRight.deleteMessages),
      canManageDirectMessages: false,
      canManageTags: false,
      canSendWelcomeMessages: false,
      isAnonymous: on.contains(AdminRight.anonymous),
    );

/// Appoints an administrator or edits one: a switch for each right, and
/// for an administrator already there, a way to dismiss them.
class AdminRightsSheet extends StatefulWidget {
  const AdminRightsSheet({
    super.key,
    required this.name,
    required this.channel,
    this.current,
  });

  final String name;
  final bool channel;

  /// The rights of an administrator being edited; null to appoint one.
  final td.ChatAdministratorRights? current;

  @override
  State<AdminRightsSheet> createState() => _AdminRightsSheetState();
}

class _AdminRightsSheetState extends State<AdminRightsSheet> {
  // A new administrator gets everything but adding others and hiding,
  // as in TelegramSwift.
  late final _on = widget.current == null
      ? {
          for (final right in AdminRight.of(channel: widget.channel))
            if (right != AdminRight.promoteMembers &&
                right != AdminRight.anonymous)
              right,
        }
      : rightsOf(widget.current!);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ManageSheetFrame(
      title: widget.current == null ? l10n.addAdmin : l10n.adminRights,
      action: l10n.save,
      onAction: () => Navigator.of(context).pop(SaveAdmin(adminRights(_on))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetCaption(l10n.adminRightsOf(widget.name)),
          for (final right in AdminRight.of(channel: widget.channel))
            ToggleRow(
              label: right.label(l10n, channel: widget.channel),
              value: _on.contains(right),
              onChanged: (on) =>
                  setState(() => on ? _on.add(right) : _on.remove(right)),
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
  changeInfo;

  String label(AppLocalizations l10n) => switch (this) {
    sendMessages => l10n.permSendMessages,
    sendMedia => l10n.permSendMedia,
    sendStickers => l10n.permSendStickers,
    sendPolls => l10n.permSendPolls,
    embedLinks => l10n.permEmbedLinks,
    inviteUsers => l10n.rightInviteUsers,
    pinMessages => l10n.rightPinMessages,
    changeInfo => l10n.rightChangeInfo,
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
    canCreateTopics: false,
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
          for (final permission in MemberPermission.values)
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
