import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../../session/providers.dart';
import '../preferences.dart';
import '../settings_style.dart';
import '../settings_window.dart';
import 'sticker_set_pages.dart';
import 'sticker_set_sheet.dart';
import 'sticker_set_tile.dart';

/// The "Stickers and emoji" entry of the settings source list.
final stickersSection = SettingsSection(
  id: 'stickers',
  icon: MgIcons.sticker,
  tint: const Color(0xFFFF9500),
  title: (l10n) => l10n.stickersAndEmoji,
  keywords: (l10n) => [
    l10n.largeEmoji,
    l10n.loopStickers,
    l10n.animatedEmoji,
    l10n.myStickers,
    l10n.customEmoji,
    l10n.trendingStickers,
    l10n.archivedStickers,
    l10n.addByLink,
  ],
  builder: (context) => const StickersPage(),
);

StickerSetsController stickerSetsOf(WidgetRef ref) =>
    ref.read(telegramSessionProvider).requireValue.stickerSets;

/// The installed sets of a kind in the user's order, following changes.
final installedSetsProvider = StreamProvider.autoDispose
    .family<List<td.StickerSetInfo>, StickerSetKind>((ref, kind) async* {
      final sets = (await ref.watch(telegramSessionProvider.future))
          .stickerSets;
      yield await sets.installed(kind);
      await for (final _ in sets.changes) {
        yield sets.installedOf(kind) ?? await sets.installed(kind);
      }
    });

/// Whether single emoji play as animations (a TDLib option).
final animatedEmojiProvider = FutureProvider.autoDispose<bool>(
  (ref) async =>
      (await ref.watch(telegramSessionProvider.future)).stickerSets
          .animatedEmoji(),
);

/// Stickers and emoji, after TelegramSwift's InstalledStickerPacksController:
/// the options, trending and archived sets, adding a set by its link, and
/// the installed sets, dragged to reorder. Custom emoji sets have a page of
/// their own with the same parts.
class StickersPage extends ConsumerWidget {
  const StickersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    final animated = ref.watch(animatedEmojiProvider).value;
    return SettingsPage(
      children: [
        SettingsGroup(
          footer: SettingsFooter(l10n.largeEmojiHint),
          children: [
            SettingsSwitchRow(
              key: const ValueKey('largeEmoji'),
              title: l10n.largeEmoji,
              value: prefs.largeEmoji,
              onChanged: (v) =>
                  notifier.update((p) => p.copyWith(largeEmoji: v)),
            ),
            SettingsSwitchRow(
              key: const ValueKey('loopStickers'),
              title: l10n.loopStickers,
              value: prefs.loopStickers,
              onChanged: (v) =>
                  notifier.update((p) => p.copyWith(loopStickers: v)),
            ),
            SettingsSwitchRow(
              key: const ValueKey('animatedEmoji'),
              title: l10n.animatedEmoji,
              value: animated ?? true,
              onChanged: animated == null
                  ? null
                  : (v) async {
                      await stickerSetsOf(ref).setAnimatedEmoji(v);
                      ref.invalidate(animatedEmojiProvider);
                    },
            ),
          ],
        ),
        const StickerSetsBody(kind: StickerSetKind.stickers),
        SettingsGroup(
          children: [
            SettingsRow(
              key: const ValueKey('customEmoji'),
              leading: const SettingsSymbol(
                icon: MgIcons.emoji,
                tint: Color(0xFFFFB800),
              ),
              title: l10n.customEmoji,
              chevron: true,
              onTap: () => SettingsNavigation.of(context).push(
                l10n.customEmoji,
                (context) => const SettingsPage(
                  children: [StickerSetsBody(kind: StickerSetKind.emoji)],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Trending, archived, add by link, and the installed sets of [kind].
class StickerSetsBody extends ConsumerStatefulWidget {
  const StickerSetsBody({super.key, required this.kind});

  final StickerSetKind kind;

  @override
  ConsumerState<StickerSetsBody> createState() => _StickerSetsBodyState();
}

class _StickerSetsBodyState extends ConsumerState<StickerSetsBody> {
  String? _error;

  bool get _emoji => widget.kind == StickerSetKind.emoji;

  /// Runs [change], saying so under the list if TDLib refuses it.
  Future<void> _try(Future<void> Function() change) async {
    setState(() => _error = null);
    try {
      await change();
    } on Object {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).saveFailed);
      }
    }
  }

  Future<void> _menu(td.StickerSetInfo set, Offset position) {
    final l10n = AppLocalizations.of(context);
    final sets = stickerSetsOf(ref);
    return showMgMenu(
      context,
      position: position,
      items: [
        MgMenuItem(
          label: l10n.archiveSet,
          onSelected: () => unawaited(_try(() => sets.archive(set))),
        ),
        MgMenuItem(
          label: l10n.remove,
          destructive: true,
          onSelected: () => unawaited(_try(() => sets.remove(set))),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = widget.kind;
    final installed = ref.watch(installedSetsProvider(kind));
    final sets = installed.value ?? const <td.StickerSetInfo>[];
    void open(String title, Widget page) =>
        SettingsNavigation.of(context).push(title, (context) => page);
    final trending = _emoji ? l10n.trendingEmoji : l10n.trendingStickers;
    final archived = _emoji ? l10n.archivedEmoji : l10n.archivedStickers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          children: [
            SettingsRow(
              key: ValueKey(('trending', kind)),
              leading: const SettingsSymbol(
                icon: _trending,
                tint: Color(0xFFFF3B30),
              ),
              title: trending,
              chevron: true,
              onTap: () => open(
                trending,
                StickerSetListPage(kind: kind, archived: false),
              ),
            ),
            SettingsRow(
              key: ValueKey(('archived', kind)),
              leading: const SettingsSymbol(
                icon: _archive,
                tint: Color(0xFF8E8E93),
              ),
              title: archived,
              chevron: true,
              onTap: () => open(
                archived,
                StickerSetListPage(kind: kind, archived: true),
              ),
            ),
            _LinkField(kind: kind),
          ],
        ),
        SettingsGroup(
          title: _emoji ? l10n.myEmoji : l10n.myStickers,
          footer: SettingsFooter(
            _error ??
                (installed.hasError
                    ? l10n.stickerSetLoadFailed
                    : l10n.stickerSetsHint),
            error: _error != null || installed.hasError,
          ),
          children: [
            if (installed.isLoading && sets.isEmpty)
              const SizedBox(
                height: 40,
                child: Center(child: SettingsSpinner()),
              )
            else if (sets.isEmpty)
              SettingsRow(title: l10n.noStickerSets)
            else
              StickerSetReorderList(
                sets: sets,
                onReorder: (from, to) => unawaited(
                  _try(() => stickerSetsOf(ref).reorder(kind, from, to)),
                ),
                onOpen: (set) =>
                    unawaited(showStickerSetSheet(context, set.name)),
                onMenu: (set, position) => unawaited(_menu(set, position)),
              ),
          ],
        ),
      ],
    );
  }
}

/// "Add by link": a t.me/addstickers or t.me/addemoji link, or a set's
/// name, opens the set's sheet.
class _LinkField extends StatefulWidget {
  const _LinkField({required this.kind});

  final StickerSetKind kind;

  @override
  State<_LinkField> createState() => _LinkFieldState();
}

class _LinkFieldState extends State<_LinkField> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _open() {
    final name = stickerSetNameOf(_text.text);
    final l10n = AppLocalizations.of(context);
    if (name == null) {
      setState(() => _error = l10n.stickerSetNotFound);
      return;
    }
    setState(() => _error = null);
    unawaited(
      showStickerSetSheet(context, name).then((found) {
        if (!mounted) return;
        if (found) {
          _text.clear();
        } else {
          setState(() => _error = l10n.stickerSetNotFound);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final style = mgTextStyle(c, height: 1.3);
    final hint = widget.kind == StickerSetKind.emoji
        ? 't.me/addemoji/…'
        : 't.me/addstickers/…';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(l10n.addByLink, style: style),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  key: ValueKey(('link', widget.kind)),
                  controller: _text,
                  style: style,
                  cursorHeight: 15,
                  textAlign: TextAlign.end,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _open(),
                  decoration: InputDecoration.collapsed(
                    hintText: hint,
                    hintStyle: style.copyWith(color: c.fg2),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ListenableBuilder(
                listenable: _text,
                builder: (context, _) => SettingsButton(
                  label: l10n.openSetLink,
                  onPressed: _text.text.trim().isEmpty ? null : _open,
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error!,
                style: mgTextStyle(
                  c,
                  size: MgType.caption,
                  color: MgDestructive.color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _trending = MgIconData(
  'trending',
  '<path d="M4 16l5-5 4 4 7-7"/><path d="M14 8h6v6"/>',
);

const _archive = MgIconData(
  'archive',
  '<rect x="3" y="4" width="18" height="5" rx="1"/>'
      '<path d="M5 9v10h14V9M10 13h4"/>',
);
