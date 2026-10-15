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

/// Archived or trending sets of [kind], each with Restore, Add or Remove,
/// a page at a time: the next one loads as the list nears its end.
class StickerSetListPage extends ConsumerStatefulWidget {
  const StickerSetListPage({
    super.key,
    required this.kind,
    required this.archived,
  });

  final StickerSetKind kind;
  final bool archived;

  /// Sets asked for at a time.
  static const pageSize = 50;

  @override
  ConsumerState<StickerSetListPage> createState() => _StickerSetListPageState();
}

class _StickerSetListPageState extends ConsumerState<StickerSetListPage> {
  /// The sets loaded so far, in Telegram's order.
  final _sets = <td.StickerSetInfo>[];
  var _loading = false;
  var _done = false;
  var _loadFailed = false;

  /// Sets added or removed here or in their sheet, by id: true when
  /// installed now.
  final _changed = <int, bool>{};
  final _busy = <int>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMore());
  }

  /// Loads the next page, unless one is loading or there are no more.
  Future<void> _loadMore() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final sets = (await ref.read(telegramSessionProvider.future)).stickerSets;
      final page = widget.archived
          ? await sets.archived(
              widget.kind,
              after: _sets.isEmpty ? 0 : _sets.last.id,
              limit: StickerSetListPage.pageSize,
            )
          : await sets.trending(
              widget.kind,
              offset: _sets.length,
              limit: StickerSetListPage.pageSize,
            );
      if (!mounted) return;
      if (!widget.archived) {
        // Seen now, so Telegram stops counting them as new.
        final unseen = [
          for (final s in page)
            if (!s.isViewed) s.id,
        ];
        unawaited(sets.viewTrending(unseen).catchError((Object _) {}));
      }
      setState(() {
        final known = {for (final s in _sets) s.id};
        _sets.addAll(page.where((s) => !known.contains(s.id)));
        _done = page.length < StickerSetListPage.pageSize;
        _loading = false;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  bool _onScroll(ScrollMetrics metrics) {
    if (metrics.axis == Axis.vertical && metrics.extentAfter < 400) {
      unawaited(_loadMore());
    }
    return false;
  }

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
    final sets = [
      for (final s in _sets)
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

    const spinner = SizedBox(
      height: 40,
      child: Center(child: SettingsSpinner()),
    );
    return NotificationListener<ScrollMetricsNotification>(
      // Also when a page leaves the list too short to scroll.
      onNotification: (n) => _onScroll(n.metrics),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) => _onScroll(n.metrics),
        child: SettingsPage(
          children: [
            SettingsGroup(
              footer: _error != null || _loadFailed
                  ? SettingsFooter(
                      _error ?? l10n.stickerSetLoadFailed,
                      error: true,
                    )
                  : null,
              children: [
                if (sets.isEmpty && (_loading || !_done && !_loadFailed))
                  spinner
                else if (sets.isEmpty)
                  SettingsRow(
                    title: widget.archived
                        ? l10n.noArchivedSets
                        : l10n.noStickerSets,
                  )
                else ...[
                  for (final set in sets)
                    StickerSetRow(
                      key: ValueKey(set.id),
                      set: set,
                      trailing: button(set),
                      onTap: () => unawaited(
                        showStickerSetSheet(
                          context,
                          set.name,
                          onInstalled: (installed) {
                            if (mounted) {
                              setState(() => _changed[set.id] = installed);
                            }
                          },
                        ),
                      ),
                    ),
                  if (_loading) spinner,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
