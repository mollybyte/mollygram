import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../chat/message_tile.dart' show SenderAvatar;
import '../contacts/presence.dart';
import '../contacts/providers.dart';
import '../home/workspace.dart';
import '../session/providers.dart';
import 'manage_sheet.dart';

/// The ⌘K commands that start a new group or channel, for the app's
/// commands. [other] gives the keywords in the other language.
List<PaletteCommand> newChatCommands(
  BuildContext Function() context,
  AppLocalizations l10n,
  AppLocalizations other,
) => [
  PaletteCommand(
    id: 'app.newGroup',
    title: l10n.newGroup,
    keywords: [other.newGroup],
    run: () => unawaited(
      showManageSheet<void>(context(), const NewChatSheet(channel: false)),
    ),
  ),
  PaletteCommand(
    id: 'app.newChannel',
    title: l10n.newChannel,
    keywords: [other.newChannel],
    run: () => unawaited(
      showManageSheet<void>(context(), const NewChatSheet(channel: true)),
    ),
  ),
];

/// Creates a group (members first, then its name) or a channel (its name
/// and description), then opens it.
class NewChatSheet extends ConsumerStatefulWidget {
  const NewChatSheet({super.key, required this.channel});

  final bool channel;

  @override
  ConsumerState<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<NewChatSheet> {
  final _search = TextEditingController();
  final _title = TextEditingController();
  final _about = TextEditingController();
  final _picked = <int>{};

  /// A group's members are chosen first; a channel starts at its name.
  late var _naming = widget.channel;
  var _busy = false;
  var _failed = false;
  String? _titleError;

  @override
  void dispose() {
    _search.dispose();
    _title.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    if (_title.text.trim().isEmpty) {
      setState(() => _titleError = l10n.chatTitleRequired);
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    final management = ref
        .read(telegramSessionProvider)
        .requireValue
        .management;
    try {
      final chatId = widget.channel
          ? await management.createChannel(
              _title.text,
              description: _about.text,
            )
          : await management.createGroup(_title.text, [..._picked]);
      if (!mounted) return;
      ref.read(workspaceControllerProvider).open(chatId);
      Navigator.of(context).pop();
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
    if (!_naming) return _members(l10n);
    return ManageSheetFrame(
      title: widget.channel ? l10n.newChannel : l10n.newGroup,
      onBack: widget.channel ? null : () => setState(() => _naming = false),
      action: l10n.create,
      busy: _busy,
      error: _failed ? l10n.createFailed : null,
      onAction: _busy ? null : _create,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MgUnderlineField(
              controller: _title,
              hintText: widget.channel ? l10n.channelName : l10n.groupName,
              autofocus: true,
              fontSize: 14,
              errorText: _titleError,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
              onSubmitted: (_) => _create(),
            ),
            if (widget.channel) ...[
              const SizedBox(height: 14),
              MgUnderlineField(
                controller: _about,
                hintText: l10n.descriptionHint,
                fontSize: 14,
                onSubmitted: (_) => _create(),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                l10n.membersCount(_picked.length + 1),
                style: mgTextStyle(
                  MgColors.of(context),
                  size: MgType.caption,
                  color: MgColors.of(context).fg2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _members(AppLocalizations l10n) {
    final c = MgColors.of(context);
    final query = _search.text.trim().toLowerCase();
    final contacts = [
      for (final user
          in ref.watch(contactsProvider).value ?? const <ContactUser>[])
        if (!user.isBot && user.name.toLowerCase().contains(query)) user,
    ];
    final now = DateTime.now();
    return ManageSheetFrame(
      title: l10n.newGroup,
      height: 460,
      action: l10n.next,
      onAction: () => setState(() => _naming = true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MgSearchField(
            controller: _search,
            hintText: l10n.addMembersHint,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Text(
                      l10n.nothingFound,
                      style: mgTextStyle(c, color: c.fg2),
                    ),
                  )
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, i) {
                      final user = contacts[i];
                      return _PickRow(
                        name: user.name,
                        status: formatPresence(
                          l10n,
                          user,
                          locale: l10n.localeName,
                          now: now,
                        ),
                        picked: _picked.contains(user.id),
                        onTap: () => setState(
                          () => _picked.remove(user.id) || _picked.add(user.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.name,
    required this.status,
    required this.picked,
    required this.onTap,
  });

  final String name;
  final String status;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      checked: picked,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
              children: [
                SenderAvatar(name: name, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(c, height: 1.3),
                      ),
                      Text(
                        status,
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: picked ? c.accent : const Color(0x00000000),
                    border: Border.all(
                      color: picked ? c.accent : c.separator,
                      width: 1.5,
                    ),
                  ),
                  child: picked
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.onAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
