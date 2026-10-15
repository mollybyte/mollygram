import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// Watches the draft for a `:word` and offers the emoji Telegram knows by
/// that keyword; [pick] puts the chosen one in place of the word.
class EmojiSuggester extends ChangeNotifier {
  EmojiSuggester({
    required this.controller,
    this.search,
    this.delay = const Duration(milliseconds: 120),
  }) {
    controller.addListener(_changed);
  }

  final RichTextEditingController controller;

  /// Emoji matching a keyword prefix, with the keyword that matched.
  Future<List<({String emoji, String keyword})>> Function(String query)? search;
  final Duration delay;

  List<({String emoji, String keyword})> _found = const [];
  List<ComposerSuggestion> _suggestions = const [];
  String? _query;
  String? _dismissed;
  Timer? _debounce;
  var _generation = 0;
  var _disposed = false;

  /// The matches as composer rows: the emoji, then its keyword. The list
  /// stays the same object until the matches change.
  List<ComposerSuggestion> get suggestions => _suggestions;

  void _changed() {
    final query = search == null ? null : controller.emojiQuery;
    if (query == _query) return;
    _query = query;
    _debounce?.cancel();
    final generation = ++_generation;
    if (query == null || query == _dismissed) {
      _dismissed = query == null ? null : _dismissed;
      _set(const []);
      return;
    }
    _dismissed = null;
    _debounce = Timer(delay, () async {
      final List<({String emoji, String keyword})> found;
      try {
        found = await search!(query);
      } on Object {
        return;
      }
      if (generation == _generation) _set(found.take(8).toList());
    });
  }

  void _set(List<({String emoji, String keyword})> found) {
    if (_disposed) return;
    if (found.isEmpty && _found.isEmpty) return;
    _found = found;
    _suggestions = [
      for (final match in found)
        ComposerSuggestion(
          title: match.keyword,
          leading: SizedBox(
            width: 26,
            child: Text(
              match.emoji,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, height: 1.2),
            ),
          ),
        ),
    ];
    notifyListeners();
  }

  /// Puts emoji [index] in place of the `:word`.
  void pick(int index) {
    if (index < 0 || index >= _found.length) return;
    final emoji = _found[index].emoji;
    _set(const []);
    controller.insertEmoji(emoji);
  }

  /// Esc: hides the popup until the `:word` changes.
  void dismiss() {
    _dismissed = _query;
    _generation++;
    _debounce?.cancel();
    _set(const []);
  }

  /// Another chat: starts afresh from its draft.
  void reset() {
    _dismissed = null;
    _query = null;
    _generation++;
    _debounce?.cancel();
    _set(const []);
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    controller.removeListener(_changed);
    super.dispose();
  }
}
