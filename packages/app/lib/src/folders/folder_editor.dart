import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../chat/message_tile.dart' show SenderAvatar;
import '../session/providers.dart';
import 'folder_chat_picker.dart';
import 'folder_icons.dart';
import 'folder_sheet.dart';

/// Opens the folder editor as a sheet: folder [id] when given, otherwise
/// a new folder that starts from [initial], such as a recommended one.
Future<void> showFolderEditor(
  BuildContext context, {
  int? id,
  ChatFolderDraft initial = const ChatFolderDraft(),
}) => showFolderSheet<void>(context, FolderEditor(id: id, initial: initial));

/// The rules of one folder, after TelegramSwift's folder editor: its icon
/// and name, the chats and kinds of chats it takes in, those it leaves
/// out, and deleting it. Nothing is saved until Save.
class FolderEditor extends ConsumerStatefulWidget {
  const FolderEditor({
    super.key,
    this.id,
    this.initial = const ChatFolderDraft(),
  });

  /// The folder edited; null for a new one.
  final int? id;
  final ChatFolderDraft initial;

  @override
  ConsumerState<FolderEditor> createState() => _FolderEditorState();
}

class _FolderEditorState extends ConsumerState<FolderEditor> {
  /// Null while an existing folder loads.
  ChatFolderDraft? _draft;
  late final _name = TextEditingController(text: widget.initial.title);
  final _nameFocus = FocusNode();
  final _chats = <int, FolderChat>{};

  /// Chats asked about, so one TDLib doesn't know reads "Deleted chat".
  final _described = <int>{};
  var _iconsOpen = false;
  var _saving = false;
  var _loadFailed = false;
  String? _error;

  ChatFoldersController get _folders =>
      ref.read(telegramSessionProvider).requireValue.folders;

  @override
  void initState() {
    super.initState();
    if (widget.id == null) {
      _draft = widget.initial;
      _nameFocus.requestFocus();
      unawaited(_describe(widget.initial));
    } else {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final draft = await _folders.folder(widget.id!);
      if (!mounted) return;
      setState(() => _draft = draft);
      _name.text = draft.title;
      await _describe(draft);
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// Fetches the titles and photos of chats not seen yet.
  Future<void> _describe(ChatFolderDraft draft) async {
    final missing = [
      for (final id in [...draft.chosenChatIds, ...draft.excludedChatIds])
        if (!_chats.containsKey(id)) id,
    ];
    if (missing.isEmpty) return;
    _described.addAll(missing);
    final found = await _folders
        .describe(missing)
        .catchError((Object _) => <FolderChat>[]);
    if (!mounted) return;
    setState(() {
      for (final chat in found) {
        _chats[chat.id] = chat;
      }
    });
  }

  void _update(ChatFolderDraft draft) => setState(() {
    _draft = draft;
    _error = null;
  });

  Set<FolderRule> _includedRules(ChatFolderDraft d) => {
    if (d.includeContacts) FolderRule.contacts,
    if (d.includeNonContacts) FolderRule.nonContacts,
    if (d.includeGroups) FolderRule.groups,
    if (d.includeChannels) FolderRule.channels,
    if (d.includeBots) FolderRule.bots,
  };

  Set<FolderRule> _excludedRules(ChatFolderDraft d) => {
    if (d.excludeMuted) FolderRule.muted,
    if (d.excludeRead) FolderRule.read,
    if (d.excludeArchived) FolderRule.archived,
  };

  ChatFolderDraft _withRule(ChatFolderDraft d, FolderRule rule, bool on) =>
      switch (rule) {
        FolderRule.contacts => d.copyWith(includeContacts: on),
        FolderRule.nonContacts => d.copyWith(includeNonContacts: on),
        FolderRule.groups => d.copyWith(includeGroups: on),
        FolderRule.channels => d.copyWith(includeChannels: on),
        FolderRule.bots => d.copyWith(includeBots: on),
        FolderRule.muted => d.copyWith(excludeMuted: on),
        FolderRule.read => d.copyWith(excludeRead: on),
        FolderRule.archived => d.copyWith(excludeArchived: on),
      };

  Future<void> _pick({required bool include}) async {
    final draft = _draft!;
    final l10n = AppLocalizations.of(context);
    // A shared folder can only list chats by name.
    final rules = draft.isShareable
        ? const <FolderRule>[]
        : include
        ? FolderRule.included
        : FolderRule.excluded;
    // TDLib caps the chats taken in and those left out separately.
    final choice = await showFolderChatPicker(
      context,
      title: include ? l10n.folderIncluded : l10n.folderExcluded,
      rules: rules,
      selectedRules: include ? _includedRules(draft) : _excludedRules(draft),
      selectedChats: include ? draft.chosenChatIds : draft.excludedChatIds,
      maxChats: _folders.maxChosenChats,
    );
    if (choice == null || !mounted) return;
    var next = _draft!;
    for (final rule in rules) {
      next = _withRule(next, rule, choice.rules.contains(rule));
    }
    final picked = choice.chatIds;
    if (include) {
      next = next.copyWith(
        pinnedChatIds: [
          for (final id in next.pinnedChatIds)
            if (picked.contains(id)) id,
        ],
        includedChatIds: [
          for (final id in picked)
            if (!next.pinnedChatIds.contains(id)) id,
        ],
        // A chat can't be both in and out.
        excludedChatIds: [
          for (final id in next.excludedChatIds)
            if (!picked.contains(id)) id,
        ],
      );
    } else {
      next = next.copyWith(
        excludedChatIds: picked,
        pinnedChatIds: [
          for (final id in next.pinnedChatIds)
            if (!picked.contains(id)) id,
        ],
        includedChatIds: [
          for (final id in next.includedChatIds)
            if (!picked.contains(id)) id,
        ],
      );
    }
    _update(next);
    await _describe(next);
  }

  void _removeChat(int id) {
    final d = _draft!;
    _update(
      d.copyWith(
        pinnedChatIds: [...d.pinnedChatIds]..remove(id),
        includedChatIds: [...d.includedChatIds]..remove(id),
        excludedChatIds: [...d.excludedChatIds]..remove(id),
      ),
    );
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || !draft.canSave || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = widget.id;
      if (id == null) {
        await _folders.create(draft);
      } else {
        await _folders.edit(id, draft);
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppLocalizations.of(context).saveFailed;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = widget.id!;
    final l10n = AppLocalizations.of(context);
    List<FolderChat> chats;
    try {
      chats = await _folders.chatsToLeave(id);
    } on Object {
      chats = const [];
    }
    if (!mounted) return;
    final leave = await showDeleteFolderConfirm(
      context,
      title: l10n.deleteFolderTitle(_draft?.title ?? ''),
      chats: chats,
    );
    if (leave == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _folders.delete(id, leaveChatIds: leave);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.saveFailed;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final draft = _draft;
    // While a save or delete is out the sheet stays, so its error shows.
    return PopScope(
      canPop: !_saving,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: SizedBox(
          width: 440,
          height: 600,
          child: Glass(
            radius: MgRadius.popover,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.id == null ? l10n.newFolder : l10n.editFolder,
                          style: mgTextStyle(c, weight: FontWeight.w600),
                        ),
                      ),
                      MgIconButton(
                        icon: MgIcons.close,
                        tooltip: l10n.close,
                        onPressed: _saving ? null : _close,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: draft == null
                      ? Center(
                          child: _loadFailed
                              ? MgTextButton(
                                  label: l10n.tryAgain,
                                  onPressed: () => unawaited(_load()),
                                )
                              : SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.6,
                                    color: c.fg2,
                                  ),
                                ),
                        )
                      : _body(context, draft),
                ),
                _bottomBar(context, draft),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _close() {
    if (!_saving) Navigator.of(context).pop();
  }

  Widget _body(BuildContext context, ChatFolderDraft draft) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final included = _includedRules(draft);
    final excluded = _excludedRules(draft);
    Widget chatRow(int id) {
      final chat = _chats[id];
      final title = chat == null
          ? (_described.contains(id) ? l10n.folderDeletedChat : '')
          : chat.isSelf
          ? l10n.folderSavedMessages
          : chat.title;
      return _EditorRow(
        key: ValueKey(('chat', id)),
        leading: SenderAvatar(
          name: title,
          size: 26,
          photo: chat?.isSelf ?? false ? null : chat?.photo,
        ),
        title: title,
        removeLabel: l10n.folderRemove,
        onRemove: () => _removeChat(id),
      );
    }

    Widget ruleRow(FolderRule rule) => _EditorRow(
      key: ValueKey(rule),
      leading: _RuleTile(rule),
      title: rule.label(l10n),
      removeLabel: l10n.folderRemove,
      onRemove: () => _update(_withRule(draft, rule, false)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      children: [
        Row(
          children: [
            _IconButton(
              iconName: draft.iconName,
              open: _iconsOpen,
              label: l10n.folderIcon,
              onTap: () => setState(() => _iconsOpen = !_iconsOpen),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NameField(
                controller: _name,
                focusNode: _nameFocus,
                hint: l10n.folderName,
                onChanged: (value) => _update(draft.copyWith(title: value)),
                onSubmitted: () => unawaited(_save()),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _iconsOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _IconGrid(
                    selected: draft.iconName,
                    onSelect: (name) {
                      _update(draft.copyWith(iconName: name));
                      setState(() => _iconsOpen = false);
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 18),
        _Box(
          title: l10n.folderIncluded,
          footer: l10n.folderIncludedHint,
          children: [
            _AddRow(
              label: l10n.folderAddChats,
              onTap: () => unawaited(_pick(include: true)),
            ),
            if (!draft.isShareable)
              for (final rule in FolderRule.included)
                if (included.contains(rule)) ruleRow(rule),
            for (final id in draft.chosenChatIds) chatRow(id),
          ],
        ),
        // A shared folder takes no rules and leaves nothing out.
        if (!draft.isShareable) ...[
          const SizedBox(height: 18),
          _Box(
            title: l10n.folderExcluded,
            footer: l10n.folderExcludedHint,
            children: [
              _AddRow(
                label: l10n.folderExcludeChats,
                onTap: () => unawaited(_pick(include: false)),
              ),
              for (final rule in FolderRule.excluded)
                if (excluded.contains(rule)) ruleRow(rule),
              for (final id in draft.excludedChatIds) chatRow(id),
            ],
          ),
        ],
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              error,
              style: mgTextStyle(
                c,
                size: MgType.caption,
                color: MgDestructive.color,
              ),
            ),
          ),
      ],
    );
  }

  Widget _bottomBar(BuildContext context, ChatFolderDraft? draft) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.separator, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
        child: Row(
          children: [
            if (widget.id != null && draft != null)
              _DestructiveButton(
                label: l10n.deleteFolder,
                onTap: _saving ? null : () => unawaited(_delete()),
              ),
            const Spacer(),
            MgTextButton(
              label: l10n.cancel,
              onPressed: _saving ? null : _close,
            ),
            const SizedBox(width: 8),
            MgPrimaryButton(
              label: widget.id == null ? l10n.createFolder : l10n.save,
              height: 28,
              loading: _saving,
              onPressed: draft != null && draft.canSave && !_saving
                  ? () => unawaited(_save())
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before deleting a folder; when it was shared with the user, its
/// [chats] are listed with checkboxes to leave them too. Completes with
/// the chats to leave, or null when cancelled.
Future<List<int>?> showDeleteFolderConfirm(
  BuildContext context, {
  required String title,
  required List<FolderChat> chats,
}) => showFolderSheet<List<int>>(
  context,
  _DeleteConfirm(title: title, chats: chats),
);

class _DeleteConfirm extends StatefulWidget {
  const _DeleteConfirm({required this.title, required this.chats});

  final String title;
  final List<FolderChat> chats;

  @override
  State<_DeleteConfirm> createState() => _DeleteConfirmState();
}

class _DeleteConfirmState extends State<_DeleteConfirm> {
  late final _leave = {for (final chat in widget.chats) chat.id};

  void _confirm() => Navigator.of(context).pop([
    for (final chat in widget.chats)
      if (_leave.contains(chat.id)) chat.id,
  ]);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _confirm,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: 320,
          child: Glass(
            radius: MgRadius.popover,
            padding: const EdgeInsets.fromLTRB(
              MgSpace.xl,
              MgSpace.xl,
              MgSpace.xl,
              MgSpace.l,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: mgTextStyle(c, weight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.chats.isEmpty
                      ? l10n.deleteFolderMessage
                      : l10n.deleteFolderLeave,
                  style: mgTextStyle(c, color: c.fg2),
                ),
                if (widget.chats.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final chat in widget.chats)
                          _LeaveRow(
                            key: ValueKey(chat.id),
                            chat: chat,
                            checked: _leave.contains(chat.id),
                            onTap: () => setState(() {
                              if (!_leave.remove(chat.id)) _leave.add(chat.id);
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MgTextButton(
                      label: l10n.cancel,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    _DestructiveButton(
                      label: l10n.delete,
                      filled: true,
                      onTap: _confirm,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveRow extends StatelessWidget {
  const _LeaveRow({
    super.key,
    required this.chat,
    required this.checked,
    required this.onTap,
  });

  final FolderChat chat;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      checked: checked,
      label: chat.title,
      onTap: onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                FolderCheck(checked: checked),
                const SizedBox(width: 10),
                SenderAvatar(name: chat.title, size: 24, photo: chat.photo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(c),
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

/// A rounded box of rows with hairlines, a caption above and a hint below.
class _Box extends StatelessWidget {
  const _Box({
    required this.title,
    required this.footer,
    required this.children,
  });

  final String title;
  final String footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text(title, style: mgTextStyle(c, weight: FontWeight.w600)),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: c.field,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 48),
                        child: SizedBox(
                          height: 0.5,
                          child: ColoredBox(color: c.separator),
                        ),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text(
            footer,
            style: mgTextStyle(
              c,
              size: MgType.caption,
              color: c.fg2,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Add chats": a plus in the accent, opening the picker.
class _AddRow extends StatefulWidget {
  const _AddRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_AddRow> createState() => _AddRowState();
}

class _AddRowState extends State<_AddRow> {
  var _hover = false;

  static const _plus = MgIconData('plus', '<path d="M12 5v14M5 12h14"/>');

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      label: widget.label,
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
            duration: const Duration(milliseconds: 120),
            color: _hover ? c.hover : const Color(0x00000000),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: MgIcon(_plus, size: 18, stroke: 2.2, color: c.accent),
                ),
                const SizedBox(width: 10),
                Text(widget.label, style: mgTextStyle(c, color: c.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A chat or a rule in the editor, with a remove button.
class _EditorRow extends StatefulWidget {
  const _EditorRow({
    super.key,
    required this.leading,
    required this.title,
    required this.removeLabel,
    required this.onRemove,
  });

  final Widget leading;
  final String title;
  final String removeLabel;
  final VoidCallback onRemove;

  @override
  State<_EditorRow> createState() => _EditorRowState();
}

class _EditorRowState extends State<_EditorRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        child: Row(
          children: [
            widget.leading,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mgTextStyle(c),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _hover ? 1 : 0.55,
              child: MgIconButton(
                icon: MgIcons.close,
                tooltip: widget.removeLabel,
                onPressed: widget.onRemove,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile(this.rule);

  final FolderRule rule;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: rule.tint, shape: BoxShape.circle),
    child: MgIcon(rule.icon, size: 15, color: const Color(0xFFFFFFFF)),
  );
}

/// The folder's icon; a click opens the icon grid under it.
class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.iconName,
    required this.open,
    required this.label,
    required this.onTap,
  });

  final String iconName;
  final bool open;
  final String label;
  final VoidCallback onTap;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        label: widget.label,
        expanded: widget.open,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.open || _hover
                    ? c.accent.withValues(alpha: 0.18)
                    : c.field,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: MgIcon(
                folderIcon(widget.iconName),
                size: 22,
                color: c.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Wrap(
          children: [
            for (final name in chatFolderIconNames)
              _IconCell(
                key: ValueKey(name),
                name: name,
                selected:
                    name == selected || (selected.isEmpty && name == 'Custom'),
                onTap: () => onSelect(name),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconCell extends StatefulWidget {
  const _IconCell({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_IconCell> createState() => _IconCellState();
}

class _IconCellState extends State<_IconCell> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.name,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.selected
                  ? c.accent
                  : _hover
                  ? c.hover
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: MgIcon(
              folderIcon(widget.name),
              size: 20,
              color: widget.selected ? c.onAccent : c.fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final style = mgTextStyle(c, height: 1.3);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLength: ChatFolderDraft.maxTitleLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              style: style,
              cursorHeight: 15,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: style.copyWith(color: c.fg2),
              ).copyWith(counterText: ''),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Text(
              '${ChatFolderDraft.maxTitleLength - controller.text.characters.length}',
              style: mgTextStyle(
                c,
                size: MgType.caption,
                color: c.fg2,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

/// A push button in the destructive red: outlined text, or [filled].
class _DestructiveButton extends StatefulWidget {
  const _DestructiveButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  State<_DestructiveButton> createState() => _DestructiveButtonState();
}

class _DestructiveButtonState extends State<_DestructiveButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = widget.onTap != null;
    const red = MgDestructive.color;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.filled
                  ? red.withValues(alpha: _hover ? 0.88 : 1)
                  : _hover && enabled
                  ? red.withValues(alpha: 0.1)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(MgRadius.control),
            ),
            child: Text(
              widget.label,
              style: mgTextStyle(
                c,
                color: widget.filled
                    ? const Color(0xFFFFFFFF)
                    : red.withValues(alpha: enabled ? 1 : 0.45),
                weight: widget.filled ? FontWeight.w600 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
