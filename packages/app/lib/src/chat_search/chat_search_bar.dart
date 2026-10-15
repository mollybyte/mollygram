import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';

/// The ⌘F capsule in the chat header: the query, "3 of 12" and arrows
/// through the results, newest first, as in the official macOS app.
///
/// ↑ or ⏎ goes to the older result, ↓ or ⇧⏎ to the newer one, Esc closes.
/// Each result is handed to [onResult], which scrolls the chat to it.
class ChatSearchBar extends StatefulWidget {
  const ChatSearchBar({
    super.key,
    required this.find,
    required this.onResult,
    required this.onClose,
    this.onCalendar,
    this.onPickSender,
  });

  /// Starts a search for a query, among one member's messages when
  /// [senderUserId] is set and among messages of [kind] when that is.
  final ChatSearchResults Function(
    String query,
    int? senderUserId,
    SharedMediaKind? kind,
  )
  find;
  final ValueChanged<int> onResult;
  final VoidCallback onClose;

  /// Asks whose messages to search, from a popover under the button's
  /// position; null when the chat has no members to pick from.
  final Future<MentionCandidate?> Function(Offset position)? onPickSender;

  /// A click on the calendar button, with the point under it where a
  /// calendar for jumping to a day goes. Absent, there is no button.
  final void Function(Offset position)? onCalendar;

  /// How long typing pauses before the search runs.
  static const debounce = Duration(milliseconds: 280);

  @override
  State<ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends State<ChatSearchBar> {
  final _text = TextEditingController();
  final _focus = FocusNode(debugLabel: 'chat search');
  Timer? _debounce;
  ChatSearchResults? _results;
  var _searching = false;
  MentionCandidate? _sender;
  SharedMediaKind? _kind;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    // The old query's results are gone: anything still on its way for
    // them is dropped, and the counter waits for the new ones.
    if (_results != null) {
      setState(() {
        _results = null;
        _searching = false;
      });
    }
    _debounce?.cancel();
    _debounce = Timer(ChatSearchBar.debounce, () => unawaited(_run()));
  }

  Future<void> _pickSender(Offset position) async {
    final picked = await widget.onPickSender!(position);
    if (picked == null || !mounted) return;
    setState(() => _sender = picked);
    _focus.requestFocus();
    await _run();
  }

  void _clearSender() {
    setState(() => _sender = null);
    _focus.requestFocus();
    unawaited(_run());
  }

  /// The kinds to narrow to, from a menu under the filter button.
  Future<void> _pickKind(Offset position) async {
    final l10n = AppLocalizations.of(context);
    SharedMediaKind? picked;
    var chosen = false;
    await showMgMenu(
      context,
      position: position,
      items: [
        MgMenuItem(label: l10n.searchAllKinds, onSelected: () => chosen = true),
        for (final kind in SharedMediaKind.values)
          MgMenuItem(
            label: kindLabel(l10n, kind),
            onSelected: () {
              chosen = true;
              picked = kind;
            },
          ),
      ],
    );
    if (!chosen || !mounted || picked == _kind) return;
    setState(() => _kind = picked);
    _focus.requestFocus();
    await _run();
  }

  void _clearKind() {
    setState(() => _kind = null);
    _focus.requestFocus();
    unawaited(_run());
  }

  /// The tab names of the shared media panel, reused for the filter.
  static String kindLabel(AppLocalizations l10n, SharedMediaKind kind) =>
      switch (kind) {
        SharedMediaKind.media => l10n.sharedMediaTab,
        SharedMediaKind.files => l10n.sharedFilesTab,
        SharedMediaKind.links => l10n.sharedLinksTab,
        SharedMediaKind.voice => l10n.sharedVoiceTab,
        SharedMediaKind.music => l10n.sharedMusicTab,
        SharedMediaKind.gifs => l10n.sharedGifsTab,
      };

  Future<void> _run() async {
    _debounce?.cancel();
    final query = _text.text.trim();
    // A member or a kind alone is a search too: everything that matches.
    if (query.isEmpty && _sender == null && _kind == null) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    final results = widget.find(query, _sender?.userId, _kind);
    setState(() {
      _results = results;
      _searching = true;
    });
    int? first;
    try {
      first = await results.start();
    } on Object {
      first = null;
    }
    // A newer query took over meanwhile.
    if (!mounted || !identical(results, _results)) return;
    setState(() => _searching = false);
    if (first != null) widget.onResult(first);
  }

  Future<void> _older() async {
    // ⏎ right after typing runs the pending search instead of waiting.
    if (_debounce?.isActive ?? false) return _run();
    final results = _results;
    if (results == null) return;
    // No result to move on from: nothing matched or the search failed,
    // so ⏎ searches again.
    if (results.index == null) return _run();
    int? id;
    try {
      id = await results.older();
    } on Object {
      id = null;
    }
    if (!mounted || !identical(results, _results)) return;
    setState(() {});
    if (id != null) widget.onResult(id);
  }

  Future<void> _newer() async {
    final results = _results;
    if (results == null) return;
    int? id;
    try {
      id = await results.newer();
    } on Object {
      id = null;
    }
    if (!mounted || !identical(results, _results)) return;
    setState(() {});
    if (id != null) widget.onResult(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final results = _results;
    final index = results?.index;
    final String? counter = switch (results) {
      null => null,
      _ when _searching => null,
      _ when index == null => l10n.searchNoResults,
      _ => l10n.searchCounter(index + 1, results.count),
    };
    void older() => unawaited(_older());
    void newer() => unawaited(_newer());

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
        const SingleActivator(LogicalKeyboardKey.enter): older,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): older,
        const SingleActivator(LogicalKeyboardKey.arrowUp): older,
        const SingleActivator(LogicalKeyboardKey.enter, shift: true): newer,
        const SingleActivator(LogicalKeyboardKey.arrowDown): newer,
      },
      // Inside the header bar, which draws the glass.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 8, 6, 8),
        child: Row(
          children: [
            if (_kind case final kind?)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _FilterChip(
                  label: kindLabel(l10n, kind),
                  onClear: _clearKind,
                ),
              ),
            if (_sender case final sender?)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _FilterChip(label: sender.name, onClear: _clearSender),
              ),
            Expanded(
              child: MgSearchField(
                hintText: l10n.searchInChat,
                controller: _text,
                focusNode: _focus,
                onChanged: _onChanged,
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              child: counter == null
                  ? const SizedBox.shrink()
                  : Text(
                      counter,
                      key: ValueKey(counter),
                      maxLines: 1,
                      style: mgTextStyle(c, size: MgType.small, color: c.fg2)
                          .copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
            ),
            const SizedBox(width: 4),
            // The arrow icon points down; turned over it points up.
            RotatedBox(
              quarterTurns: 2,
              child: MgIconButton(
                icon: MgIcons.arrowDown,
                tooltip: l10n.searchOlder,
                onPressed: results?.hasOlder ?? false ? older : null,
              ),
            ),
            MgIconButton(
              icon: MgIcons.arrowDown,
              tooltip: l10n.searchNewer,
              onPressed: results?.hasNewer ?? false ? newer : null,
            ),
            Builder(
              builder: (context) => MgIconButton(
                icon: MgIcons.file,
                tooltip: l10n.searchFilter,
                selected: _kind != null,
                onPressed: () {
                  final box = context.findRenderObject()! as RenderBox;
                  unawaited(
                    _pickKind(
                      box.localToGlobal(
                        Offset(box.size.width / 2, box.size.height),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.onPickSender != null)
              Builder(
                builder: (context) => MgIconButton(
                  icon: MgIcons.profile,
                  tooltip: l10n.searchBySender,
                  selected: _sender != null,
                  onPressed: () {
                    final box = context.findRenderObject()! as RenderBox;
                    unawaited(
                      _pickSender(
                        box.localToGlobal(
                          Offset(box.size.width / 2, box.size.height),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (widget.onCalendar case final onCalendar?)
              Builder(
                builder: (context) => MgIconButton(
                  icon: MgIcons.recent,
                  tooltip: l10n.searchByDate,
                  onPressed: () {
                    final box = context.findRenderObject()! as RenderBox;
                    onCalendar(
                      box.localToGlobal(
                        Offset(box.size.width / 2, box.size.height),
                      ),
                    );
                  },
                ),
              ),
            MgIconButton(
              icon: MgIcons.close,
              tooltip: l10n.close,
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// A filter the search is narrowed to, a member or a kind of message,
/// shown before the field with a way to drop it.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 24,
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.only(left: 9, right: 2),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mgTextStyle(
                c,
                size: MgType.small,
                weight: FontWeight.w500,
                color: c.onAccent,
                height: 1.2,
              ),
            ),
          ),
          MgIconButton(
            icon: MgIcons.close,
            tooltip: l10n.close,
            iconSize: 12,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
