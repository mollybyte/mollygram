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
  });

  /// Starts a search for a query.
  final ChatSearchResults Function(String query) find;
  final ValueChanged<int> onResult;
  final VoidCallback onClose;

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

  Future<void> _run() async {
    _debounce?.cancel();
    final query = _text.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    final results = widget.find(query);
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
      child: Glass(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(7, 7, 4, 7),
        child: Row(
          children: [
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
