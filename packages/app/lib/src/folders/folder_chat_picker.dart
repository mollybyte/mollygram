import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../chat/message_tile.dart' show SenderAvatar;
import '../session/providers.dart';
import 'folder_icons.dart';
import 'folder_sheet.dart';

/// A rule of a folder that takes in or leaves out a whole kind of chat.
enum FolderRule {
  contacts,
  nonContacts,
  groups,
  channels,
  bots,
  muted,
  read,
  archived;

  /// The rules the "Included chats" picker offers.
  static const included = [contacts, nonContacts, groups, channels, bots];

  /// The rules the "Excluded chats" picker offers.
  static const excluded = [muted, read, archived];

  String label(AppLocalizations l10n) => switch (this) {
    contacts => l10n.folderContacts,
    nonContacts => l10n.folderNonContacts,
    groups => l10n.folderGroups,
    channels => l10n.folderChannels,
    bots => l10n.folderBots,
    muted => l10n.folderMuted,
    read => l10n.folderRead,
    archived => l10n.folderArchived,
  };

  MgIconData get icon => switch (this) {
    contacts => folderIcon('Private'),
    nonContacts => _nonContact,
    groups => folderIcon('Groups'),
    channels => folderIcon('Channels'),
    bots => folderIcon('Bots'),
    muted => MgIcons.muted,
    read => _read,
    archived => _archive,
  };

  /// The tile color behind [icon], as in TelegramSwift.
  Color get tint => switch (this) {
    contacts => const Color(0xFF0A84FF),
    nonContacts => const Color(0xFF30B0C7),
    groups => const Color(0xFF34C759),
    channels => const Color(0xFFFF9500),
    bots => const Color(0xFF5E5CE6),
    muted => const Color(0xFFFF453A),
    read => const Color(0xFF34C759),
    archived => const Color(0xFF8E8E93),
  };
}

const _nonContact = MgIconData(
  'folderNonContacts',
  '<circle cx="10" cy="8.5" r="3.5"/><path d="M3.5 20a6.5 6.5 0 0 1 10-5.5"/>'
      '<path d="M16.5 15.5l4 4M20.5 15.5l-4 4"/>',
);

const _read = MgIconData(
  'folderRead',
  '<path d="M3 12.5l4 4 7-8M11.5 15.5l1 1 8-8.5"/>',
);

const _archive = MgIconData(
  'folderArchive',
  '<rect x="3.5" y="4.5" width="17" height="4.5" rx="1"/>'
      '<path d="M5 9v9a1.5 1.5 0 0 0 1.5 1.5h11A1.5 1.5 0 0 0 19 18V9'
      'M10 12.5h4"/>',
);

/// What the picker hands back: the rules and the chats that are checked.
typedef FolderChatChoice = ({Set<FolderRule> rules, List<int> chatIds});

/// The chat picker sheet of the folder editor, after TelegramSwift's: the
/// [rules] to tick on top, then the chats with checkboxes and a search.
/// At most [maxChats] chats can be checked. Completes with the choice on
/// Done, or null when cancelled.
Future<FolderChatChoice?> showFolderChatPicker(
  BuildContext context, {
  required String title,
  required List<FolderRule> rules,
  required Set<FolderRule> selectedRules,
  required List<int> selectedChats,
  int? maxChats,
}) => showFolderSheet<FolderChatChoice>(
  context,
  FolderChatPicker(
    title: title,
    rules: rules,
    selectedRules: selectedRules,
    selectedChats: selectedChats,
    maxChats: maxChats,
  ),
);

class FolderChatPicker extends ConsumerStatefulWidget {
  const FolderChatPicker({
    super.key,
    required this.title,
    required this.rules,
    required this.selectedRules,
    required this.selectedChats,
    this.maxChats,
  });

  final String title;
  final List<FolderRule> rules;
  final Set<FolderRule> selectedRules;
  final List<int> selectedChats;
  final int? maxChats;

  /// How long typing pauses before TDLib is asked.
  static const debounce = Duration(milliseconds: 220);

  @override
  ConsumerState<FolderChatPicker> createState() => _FolderChatPickerState();
}

class _FolderChatPickerState extends ConsumerState<FolderChatPicker> {
  late final _rules = {...widget.selectedRules};
  late final _chats = [...widget.selectedChats];
  final _search = FocusNode();
  Timer? _debounce;
  var _query = '';
  var _searchId = 0;

  /// The checked chats as they were when the sheet opened, then the main
  /// list; or the chats matching [_query].
  List<FolderChat>? _shown;

  /// The query [_shown] was loaded for.
  var _shownQuery = '';

  /// Checked chats known to be secret: they don't count toward the limit.
  final _secret = <int>{};

  /// A click tried to check one chat too many.
  var _overLimit = false;

  int get _counted => _chats.where((id) => !_secret.contains(id)).length;

  ChatFoldersController get _folders =>
      ref.read(telegramSessionProvider).requireValue.folders;

  @override
  void initState() {
    super.initState();
    _search.requestFocus();
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String query) {
    _query = query;
    _debounce?.cancel();
    _debounce = Timer(FolderChatPicker.debounce, () => unawaited(_load()));
  }

  Future<void> _load() async {
    final id = ++_searchId;
    final query = _query.trim();
    List<FolderChat> shown;
    try {
      final found = await _folders.candidates(query: query);
      if (query.isEmpty) {
        final known = {for (final c in found) c.id};
        final checked = await _folders.describe([
          for (final id in widget.selectedChats)
            if (!known.contains(id)) id,
        ]);
        shown = [...checked, ...found];
      } else {
        shown = found;
      }
    } on Object {
      shown = const [];
    }
    if (!mounted || id != _searchId) return;
    setState(() {
      _shown = shown;
      _shownQuery = query;
      for (final chat in shown) {
        if (chat.isSecret) _secret.add(chat.id);
      }
    });
  }

  void _toggleChat(int id) {
    setState(() {
      _overLimit = false;
      if (_chats.remove(id)) return;
      final max = widget.maxChats;
      if (max != null && !_secret.contains(id) && _counted >= max) {
        _overLimit = true;
        return;
      }
      _chats.add(id);
    });
  }

  void _done() =>
      Navigator.of(context).pop((rules: {..._rules}, chatIds: [..._chats]));

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final shown = _shown;
    final searching = _shownQuery.isNotEmpty;
    final items = <Widget>[
      if (!searching && widget.rules.isNotEmpty) ...[
        _Caption(l10n.folderChatTypes),
        for (final rule in widget.rules)
          _PickRow(
            key: ValueKey(rule),
            leading: _RuleSymbol(rule),
            title: rule.label(l10n),
            checked: _rules.contains(rule),
            onTap: () => setState(() {
              if (!_rules.remove(rule)) _rules.add(rule);
            }),
          ),
        _Caption(l10n.folderChats),
      ],
      if (shown != null)
        for (final chat in shown)
          _PickRow(
            key: ValueKey(chat.id),
            leading: SenderAvatar(
              name: chat.isSelf ? l10n.folderSavedMessages : chat.title,
              size: 30,
              photo: chat.isSelf ? null : chat.photo,
            ),
            title: chat.isSelf ? l10n.folderSavedMessages : chat.title,
            subtitle: switch (chat.kind) {
              FolderChatKind.bot => l10n.folderBot,
              FolderChatKind.group => l10n.folderGroup,
              FolderChatKind.channel => l10n.folderChannel,
              FolderChatKind.user => null,
            },
            checked: _chats.contains(chat.id),
            onTap: () => _toggleChat(chat.id),
          ),
    ];
    final max = widget.maxChats;
    // Already over, such as after the limit went down: Done waits.
    final over = max != null && _counted > max;
    final warn = _overLimit || over;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: SizedBox(
        width: 380,
        height: 540,
        child: Glass(
          radius: MgRadius.popover,
          padding: const EdgeInsets.fromLTRB(
            MgSpace.ml,
            MgSpace.l,
            MgSpace.ml,
            MgSpace.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: mgTextStyle(c, weight: FontWeight.w600),
                      ),
                    ),
                    if (max != null)
                      Text(
                        l10n.folderChatsCounter(_counted, max),
                        style: mgTextStyle(
                          c,
                          size: MgType.caption,
                          color: warn ? MgDestructive.color : c.fg2,
                        ),
                      ),
                  ],
                ),
              ),
              MgSearchField(
                focusNode: _search,
                hintText: l10n.forwardSearch,
                onChanged: _onQuery,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: shown == null
                    ? const SizedBox.shrink()
                    : searching && shown.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noChatsFound,
                          style: mgTextStyle(c, color: c.fg2),
                        ),
                      )
                    : ListView(children: items),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: warn && max != null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                        child: Text(
                          l10n.folderChatsLimit(max),
                          style: mgTextStyle(
                            c,
                            size: MgType.caption,
                            color: MgDestructive.color,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MgTextButton(
                    label: l10n.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  MgPrimaryButton(
                    label: l10n.done,
                    onPressed: over ? null : _done,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: Text(
        text,
        style: mgTextStyle(
          c,
          size: MgType.caption,
          weight: FontWeight.w600,
          color: c.fg2,
        ),
      ),
    );
  }
}

/// The tinted symbol of a rule, like a settings section's.
class _RuleSymbol extends StatelessWidget {
  const _RuleSymbol(this.rule);

  final FolderRule rule;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: rule.tint, shape: BoxShape.circle),
    child: MgIcon(rule.icon, size: 17, color: const Color(0xFFFFFFFF)),
  );
}

/// A row with a round checkbox on the right; a click anywhere toggles it.
class _PickRow extends StatefulWidget {
  const _PickRow({
    super.key,
    required this.leading,
    required this.title,
    required this.checked,
    required this.onTap,
    this.subtitle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool checked;
  final VoidCallback onTap;

  @override
  State<_PickRow> createState() => _PickRowState();
}

class _PickRowState extends State<_PickRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final subtitle = widget.subtitle;
    return Semantics(
      checked: widget.checked,
      label: widget.title,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: MgMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _hover ? c.hover : const Color(0x00000000),
              borderRadius: BorderRadius.circular(MgRadius.control),
            ),
            child: Row(
              children: [
                widget.leading,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(c, height: 1.3),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
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
                const SizedBox(width: 8),
                FolderCheck(checked: widget.checked),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round macOS-style checkbox: an outline, or the accent with a tick.
class FolderCheck extends StatelessWidget {
  const FolderCheck({super.key, required this.checked});

  final bool checked;

  static const _tick = MgIconData('tick', '<path d="M6 12.5l4 4 8-9"/>');

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? c.accent : const Color(0x00000000),
        border: Border.all(
          color: checked ? c.accent : c.fg2.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: checked ? 1 : 0,
        child: MgIcon(_tick, size: 12, stroke: 2.6, color: c.onAccent),
      ),
    );
  }
}
