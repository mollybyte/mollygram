import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import 'manage_sheet.dart';

/// The user's invite links to a group or channel: the primary one with
/// Copy and Revoke, the additional ones, and a form for a new one.
class InviteLinksSheet extends ConsumerStatefulWidget {
  const InviteLinksSheet({super.key, required this.chatId, this.now});

  final int chatId;

  /// The time expiry is measured from; the clock by default.
  final DateTime Function()? now;

  @override
  ConsumerState<InviteLinksSheet> createState() => _InviteLinksSheetState();
}

class _InviteLinksSheetState extends ConsumerState<InviteLinksSheet> {
  late final ChatManagement _management = ref
      .read(telegramSessionProvider)
      .requireValue
      .management;
  List<td.ChatInviteLink>? _links;
  var _creating = false;
  var _failed = false;

  /// The link whose "Copied" is showing.
  String? _copied;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final links = await _management.inviteLinks(widget.chatId);
      if (mounted) {
        setState(() {
          _links = links;
          _failed = false;
        });
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _copy(String link) {
    unawaited(Clipboard.setData(ClipboardData(text: link)));
    _copiedTimer?.cancel();
    setState(() => _copied = link);
    _copiedTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = null);
    });
  }

  Future<void> _revoke(td.ChatInviteLink link) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.revokeLinkTitle,
      message: link.isPrimary
          ? l10n.revokePrimaryMessage
          : l10n.revokeLinkMessage,
      confirmLabel: l10n.revokeLink,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null) return;
    try {
      await _management.revokeLink(widget.chatId, link);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
    await _load();
  }

  Future<void> _createPrimary() async {
    try {
      await _management.createPrimaryLink(widget.chatId);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_creating) {
      return _NewLinkForm(
        chatId: widget.chatId,
        onBack: () => setState(() => _creating = false),
        onCreated: (link) {
          setState(() {
            _creating = false;
            _links = [...?_links, link];
          });
          _copy(link.inviteLink);
        },
      );
    }
    final c = MgColors.of(context);
    final links = _links;
    final primary = links?.where((l) => l.isPrimary).firstOrNull;
    final others = [...?links?.where((l) => !l.isPrimary)];
    final now = (widget.now ?? DateTime.now)();
    return ManageSheetFrame(
      title: l10n.inviteLinks,
      height: 460,
      error: _failed ? l10n.saveFailed : null,
      child: links == null
          ? const SizedBox.shrink()
          : ListView(
              children: [
                SheetCaption(l10n.primaryLink),
                if (primary == null)
                  _Row(
                    title: l10n.createPrimaryLink,
                    accent: true,
                    onTap: () => unawaited(_createPrimary()),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.field,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      primary.inviteLink.replaceFirst('https://', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(c),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      MgTextButton(
                        label: _copied == primary.inviteLink
                            ? l10n.copied
                            : l10n.copyLink,
                        onPressed: () => _copy(primary.inviteLink),
                      ),
                      MgTextButton(
                        label: l10n.revokeLink,
                        onPressed: () => unawaited(_revoke(primary)),
                      ),
                    ],
                  ),
                ],
                SheetCaption(l10n.additionalLinks),
                _Row(
                  title: l10n.createLink,
                  accent: true,
                  onTap: () => setState(() => _creating = true),
                ),
                for (final link in others)
                  _Row(
                    title: _copied == link.inviteLink
                        ? l10n.copied
                        : link.name.isNotEmpty
                        ? link.name
                        : link.inviteLink.replaceFirst('https://', ''),
                    subtitle: describeLink(l10n, link, now),
                    onTap: () => _copy(link.inviteLink),
                    onRevoke: () => unawaited(_revoke(link)),
                    revokeLabel: l10n.revokeLink,
                  ),
              ],
            ),
    );
  }
}

/// "3 joined · expires Oct 20", "expired", "10 of 50 joined".
String describeLink(
  AppLocalizations l10n,
  td.ChatInviteLink link,
  DateTime now,
) {
  final parts = <String>[
    if (link.memberLimit > 0)
      l10n.linkJoinedOf(link.memberCount, link.memberLimit)
    else
      l10n.linkJoined(link.memberCount),
    if (link.createsJoinRequest) l10n.linkApproval,
  ];
  if (link.expirationDate > 0) {
    final expires = DateTime.fromMillisecondsSinceEpoch(
      link.expirationDate * 1000,
    );
    parts.add(
      expires.isBefore(now)
          ? l10n.linkExpired
          : l10n.linkExpires(DateFormat.MMMd(l10n.localeName).format(expires)),
    );
  }
  return parts.join(' · ');
}

class _Row extends StatefulWidget {
  const _Row({
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.accent = false,
    this.onRevoke,
    this.revokeLabel = '',
  });

  final String title;
  final String subtitle;
  final bool accent;
  final VoidCallback onTap;
  final VoidCallback? onRevoke;
  final String revokeLabel;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _hover ? c.hover : const Color(0x00000000),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(
                        c,
                        color: widget.accent ? c.accent : c.fg,
                        height: 1.3,
                      ),
                    ),
                    if (widget.subtitle.isNotEmpty)
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(
                          c,
                          size: MgType.caption,
                          color: c.fg2,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.onRevoke != null)
                MgIconButton(
                  icon: MgIcons.trash,
                  tooltip: widget.revokeLabel,
                  iconSize: 15,
                  onPressed: widget.onRevoke,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How long a new link works, from now.
enum _Expiry { never, day, week, month }

/// A new additional link: a name, how long it works, how many may join
/// by it, and whether an administrator approves them.
class _NewLinkForm extends ConsumerStatefulWidget {
  const _NewLinkForm({
    required this.chatId,
    required this.onBack,
    required this.onCreated,
  });

  final int chatId;
  final VoidCallback onBack;
  final ValueChanged<td.ChatInviteLink> onCreated;

  @override
  ConsumerState<_NewLinkForm> createState() => _NewLinkFormState();
}

class _NewLinkFormState extends ConsumerState<_NewLinkForm> {
  final _name = TextEditingController();
  var _expiry = _Expiry.never;
  var _limit = 0;
  var _requests = false;
  var _busy = false;
  var _failed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final now = DateTime.now();
    try {
      final link = await ref
          .read(telegramSessionProvider)
          .requireValue
          .management
          .createLink(
            widget.chatId,
            name: _name.text,
            expiresAt: switch (_expiry) {
              _Expiry.never => null,
              _Expiry.day => now.add(const Duration(days: 1)),
              _Expiry.week => now.add(const Duration(days: 7)),
              _Expiry.month => now.add(const Duration(days: 30)),
            },
            memberLimit: _limit,
            joinRequests: _requests,
          );
      if (mounted) widget.onCreated(link);
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ManageSheetFrame(
      title: l10n.newLink,
      onBack: widget.onBack,
      action: l10n.create,
      busy: _busy,
      error: _failed ? l10n.saveFailed : null,
      onAction: _busy ? null : _create,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MgUnderlineField(
              controller: _name,
              hintText: l10n.linkNameHint,
              autofocus: true,
              fontSize: 14,
              onSubmitted: (_) {
                if (!_busy) unawaited(_create());
              },
            ),
            SheetCaption(l10n.linkDuration),
            ChoiceRow<_Expiry>(
              value: _expiry,
              onChanged: (value) => setState(() => _expiry = value),
              options: [
                (_Expiry.never, l10n.noLimit),
                (_Expiry.day, l10n.oneDay),
                (_Expiry.week, l10n.oneWeek),
                (_Expiry.month, l10n.oneMonth),
              ],
            ),
            SheetCaption(l10n.linkMemberLimit),
            ChoiceRow<int>(
              value: _requests ? 0 : _limit,
              // A link that asks to join can't have a limit.
              onChanged: _requests
                  ? null
                  : (value) => setState(() => _limit = value),
              options: [
                (0, l10n.noLimit),
                (10, '10'),
                (50, '50'),
                (100, '100'),
              ],
            ),
            const SizedBox(height: 6),
            ToggleRow(
              label: l10n.linkRequestApproval,
              value: _requests,
              onChanged: (value) => setState(() => _requests = value),
            ),
          ],
        ),
      ),
    );
  }
}
