import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import '../../../l10n/app_localizations.dart';
import '../../session/providers.dart';
import '../settings_style.dart';
import 'sticker_set_sheet.dart';
import 'sticker_set_tile.dart';
import 'stickers_page.dart';

/// Archived sets, newest first, or the sets Telegram features now.
final stickerSetListProvider = FutureProvider.autoDispose
    .family<List<td.StickerSetInfo>, (StickerSetKind, bool)>((ref, key) async {
      final (kind, archived) = key;
      final sets = (await ref.watch(telegramSessionProvider.future))
          .stickerSets;
      return archived
          ? sets.archived(kind, limit: 100)
          : sets.trending(kind, limit: 100);
    });

/// Archived or trending sets of [kind], each with Restore, Add or Remove.
class StickerSetListPage extends ConsumerStatefulWidget {
  const StickerSetListPage({
    super.key,
    required this.kind,
    required this.archived,
  });

  final StickerSetKind kind;
  final bool archived;

  @override
  ConsumerState<StickerSetListPage> createState() => _StickerSetListPageState();
}

class _StickerSetListPageState extends ConsumerState<StickerSetListPage> {
  /// Sets added or removed here, by id: true when installed now.
  final _changed = <int, bool>{};
  final _busy = <int>{};
  String? _error;

  Future<void> _toggle(td.StickerSetInfo set, bool install) async {
    setState(() {
      _busy.add(set.id);
      _error = null;
    });
    final sets = stickerSetsOf(ref);
    try {
      install
          ? await sets.install(set.id, widget.kind)
          : await sets.remove(set);
      _changed[set.id] = install;
    } on Object {
      if (mounted) _error = AppLocalizations.of(context).saveFailed;
    }
    if (mounted) setState(() => _busy.remove(set.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final key = (widget.kind, widget.archived);
    final list = ref.watch(stickerSetListProvider(key));
    final sets = [
      for (final s in list.value ?? const <td.StickerSetInfo>[])
        // A restored set leaves the archive.
        if (!(widget.archived && _changed[s.id] == true)) s,
    ];
    Widget button(td.StickerSetInfo set) {
      final installed = _changed[set.id] ?? set.isInstalled;
      final busy = _busy.contains(set.id);
      if (busy) return const SettingsSpinner();
      return SettingsButton(
        key: ValueKey(('set', set.id)),
        label: widget.archived
            ? l10n.restoreSet
            : installed
            ? l10n.remove
            : l10n.addSet,
        onPressed: () => unawaited(_toggle(set, !installed)),
      );
    }

    return SettingsPage(
      children: [
        SettingsGroup(
          footer: _error != null || list.hasError
              ? SettingsFooter(_error ?? l10n.stickerSetLoadFailed, error: true)
              : null,
          children: [
            if (list.isLoading)
              const SizedBox(
                height: 40,
                child: Center(child: SettingsSpinner()),
              )
            else if (sets.isEmpty)
              SettingsRow(
                title: widget.archived
                    ? l10n.noArchivedSets
                    : l10n.noStickerSets,
              )
            else
              for (final set in sets)
                StickerSetRow(
                  key: ValueKey(set.id),
                  set: set,
                  trailing: button(set),
                  onTap: () =>
                      unawaited(showStickerSetSheet(context, set.name)),
                ),
          ],
        ),
      ],
    );
  }
}
