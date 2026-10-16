import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../folders/folder_editor.dart';
import '../folders/folder_icons.dart';
import '../folders/folder_providers.dart';
import '../session/providers.dart';
import 'settings_style.dart';
import 'settings_window.dart';

/// The "Chat folders" entry of the settings source list.
final foldersSection = SettingsSection(
  id: 'folders',
  icon: folderIcon('Custom'),
  tint: const Color(0xFF0A84FF),
  title: (l10n) => l10n.chatFolders,
  keywords: (l10n) => [
    l10n.createFolder,
    l10n.recommendedFolders,
    l10n.folderIncluded,
    l10n.folderExcluded,
  ],
  builder: (context) => const FoldersPage(),
);

/// Chat folders, after TelegramSwift's ChatListFiltersListController: the
/// folders in sidebar order, dragged by their handles to reorder, "Create
/// folder", and the folders Telegram suggests.
class FoldersPage extends ConsumerStatefulWidget {
  const FoldersPage({super.key});

  @override
  ConsumerState<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends ConsumerState<FoldersPage> {
  String? _error;

  /// Recommended folders being added, hidden right away.
  final _adding = <String>{};

  ChatFoldersController get _folders =>
      ref.read(telegramSessionProvider).requireValue.folders;

  Future<void> _reorder(
    List<ChatFolderSummary> folders,
    int from,
    int to,
  ) async {
    final ids = [for (final f in folders) f.id];
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    setState(() => _error = null);
    try {
      await _folders.reorder(ids);
    } on Object {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).saveFailed);
      }
    }
  }

  Future<void> _addRecommended(RecommendedChatFolder recommended) async {
    final title = recommended.folder.title;
    setState(() {
      _adding.add(title);
      _error = null;
    });
    try {
      await _folders.create(recommended.folder);
    } on Object {
      if (!mounted) return;
      setState(() {
        _adding.remove(title);
        _error = AppLocalizations.of(context).saveFailed;
      });
      return;
    }
    // The suggestions come back without it; only then is it let go, so
    // it doesn't show again in between.
    try {
      ref.invalidate(recommendedFoldersProvider);
      await ref.read(recommendedFoldersProvider.future);
    } on Object {
      // A list that fails to load shows nothing anyway.
    }
    if (mounted) setState(() => _adding.remove(title));
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final folders = ref.watch(folderSummariesProvider).value ?? const [];
    final recommended = [
      for (final r
          in ref.watch(recommendedFoldersProvider).value ??
              const <RecommendedChatFolder>[])
        if (!_adding.contains(r.folder.title)) r,
    ];
    final controller = _folders;
    final canCreate = folders.length < controller.maxFolders;
    return SettingsPage(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
          child: Text(
            l10n.chatFoldersHint,
            style: mgTextStyle(c, color: c.fg2, height: 1.35),
          ),
        ),
        SettingsGroup(
          title: l10n.chatFolders,
          footer: SettingsFooter(
            _error ??
                (canCreate
                    ? l10n.folderReorderHint
                    : l10n.folderLimit(controller.maxFolders)),
            error: _error != null || !canCreate,
          ),
          children: [
            SettingsRow(
              key: const ValueKey('createFolder'),
              leading: SettingsSymbol(
                icon: _plus,
                tint: canCreate ? c.accent : c.fg2,
              ),
              title: l10n.createFolder,
              onTap: canCreate
                  ? () => unawaited(showFolderEditor(context))
                  : null,
            ),
            if (folders.isNotEmpty)
              _FolderList(
                folders: folders,
                onOpen: (folder) =>
                    unawaited(showFolderEditor(context, id: folder.id)),
                onReorder: (from, to) => unawaited(_reorder(folders, from, to)),
              ),
          ],
        ),
        if (recommended.isNotEmpty && canCreate)
          SettingsGroup(
            key: const ValueKey('recommended'),
            title: l10n.recommendedFolders,
            children: [
              for (final r in recommended)
                SettingsRow(
                  key: ValueKey(('recommended', r.folder.title)),
                  leading: SettingsSymbol(
                    icon: folderIcon(r.folder.iconName),
                    tint: const Color(0xFF8E8E93),
                  ),
                  title: r.folder.title,
                  subtitle: r.description,
                  trailing: SettingsButton(
                    label: l10n.folderAdd,
                    onPressed: () => unawaited(_addRecommended(r)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

const _plus = MgIconData('plus', '<path d="M12 5v14M5 12h14"/>');

/// The folders, reordered by dragging their handles; the rows part to
/// make room and the dragged one lifts.
class _FolderList extends StatelessWidget {
  const _FolderList({
    required this.folders,
    required this.onOpen,
    required this.onReorder,
  });

  final List<ChatFolderSummary> folders;
  final ValueChanged<ChatFolderSummary> onOpen;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = SettingsColors.of(context);
    final l10n = AppLocalizations.of(context);
    final list = ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: onReorder,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(animation.value);
          return Transform.scale(
            scale: 1 + 0.02 * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: s.group,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.18 * t),
                    blurRadius: 16 * t,
                    offset: Offset(0, 4 * t),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: child,
      ),
      children: [
        for (var i = 0; i < folders.length; i++)
          SizedBox(
            key: ValueKey(folders[i].id),
            height: _rowHeight,
            child: SettingsRow(
              leading: SettingsSymbol(
                icon: folderIcon(folders[i].iconName),
                tint: c.accent,
              ),
              title: folders[i].title,
              onTap: () => onOpen(folders[i]),
              trailing: ReorderableDragStartListener(
                index: i,
                child: _Handle(label: l10n.folderReorder),
              ),
            ),
          ),
      ],
    );
    // The hairlines belong to the slots, not the rows: none travels with
    // a dragged row. The group draws the one above the first.
    return Stack(
      children: [
        list,
        Positioned.fill(
          child: IgnorePointer(
            child: Column(
              children: [
                for (var i = 0; i < folders.length; i++)
                  SizedBox(
                    height: _rowHeight,
                    child: i == 0
                        ? null
                        : Align(
                            alignment: Alignment.topCenter,
                            // From the title on, past the 24 symbol.
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: settingsInset + 24 + 10,
                                right: settingsInset,
                              ),
                              child: Container(height: 0.5, color: c.separator),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Every folder row is this tall, so the hairlines can sit between the
  /// slots.
  static const _rowHeight = 40.0;
}

/// Three short lines that brighten under the pointer, with a grab cursor.
class _Handle extends StatefulWidget {
  const _Handle({required this.label});

  final String label;

  @override
  State<_Handle> createState() => _HandleState();
}

class _HandleState extends State<_Handle> {
  var _hover = false;

  static const _grip = MgIconData(
    'grip',
    '<path d="M6 8.5h12M6 12h12M6 15.5h12"/>',
  );

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _hover ? 1 : 0.55,
            child: MgIcon(_grip, size: 18, color: c.fg2),
          ),
        ),
      ),
    );
  }
}
