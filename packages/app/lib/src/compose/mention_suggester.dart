import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../chat/message_tile.dart' show SenderAvatar;

/// Watches the draft for an @word in a group and offers the members that
/// match it; [pick] puts the chosen one in the draft.
class MentionSuggester extends ChangeNotifier {
  MentionSuggester({
    required this.controller,
    this.search,
    this.delay = const Duration(milliseconds: 120),
  }) {
    controller.addListener(_changed);
  }

  final RichTextEditingController controller;

  /// Members of the current chat matching a query; null outside groups.
  Future<List<MentionCandidate>> Function(String query)? search;
  final Duration delay;

  List<MentionCandidate> _candidates = const [];
  List<ComposerSuggestion> _suggestions = const [];
  String? _query;

  /// The query Esc dismissed; the popup stays away until it changes.
  String? _dismissed;
  Timer? _debounce;
  var _generation = 0;
  var _disposed = false;

  /// The members offered now, best match first.
  List<MentionCandidate> get candidates => _candidates;

  /// [candidates] as composer rows. The list stays the same object until
  /// the candidates change, so the composer keeps its highlight.
  List<ComposerSuggestion> get suggestions => _suggestions;

  void _changed() {
    final query = search == null ? null : controller.mentionQuery;
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
      final List<MentionCandidate> found;
      try {
        found = await search!(query);
      } on Object {
        return;
      }
      // The user typed on while the search ran.
      if (generation == _generation) _set(found);
    });
  }

  void _set(List<MentionCandidate> candidates) {
    if (_disposed) return;
    if (candidates.isEmpty && _candidates.isEmpty) return;
    _candidates = candidates;
    _suggestions = [
      for (final candidate in candidates)
        ComposerSuggestion(
          title: candidate.name,
          subtitle: candidate.username.isEmpty ? '' : '@${candidate.username}',
          leading: SenderAvatar(
            name: candidate.name,
            size: 26,
            photo: candidate.photo,
          ),
        ),
    ];
    notifyListeners();
  }

  /// Puts candidate [index] in place of the @word.
  void pick(int index) {
    if (index < 0 || index >= _candidates.length) return;
    final candidate = _candidates[index];
    _set(const []);
    controller.insertMention(
      name: candidate.name,
      username: candidate.username,
      userId: candidate.userId,
    );
  }

  /// Esc: hides the popup until the @word changes.
  void dismiss() {
    _dismissed = _query;
    _generation++;
    _debounce?.cancel();
    _set(const []);
  }

  /// Another chat: forgets what Esc dismissed and looks at the draft
  /// again, so an @word carried over is offered in the new chat.
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
    // A search still running must not report to a disposed listener.
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    controller.removeListener(_changed);
    super.dispose();
  }
}

/// Searches the members of [chatId] while it is a group; in other chats
/// an @ offers nobody.
Future<List<MentionCandidate>> Function(String query) mentionSearchFor(
  MentionSearch mentions,
  bool Function() isGroup,
  int chatId,
) =>
    (query) => isGroup()
    ? mentions.search(chatId, query)
    : Future.value(const <MentionCandidate>[]);
