import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// Watches the draft for `@bot query` and asks that inline bot for its
/// results, for the panel over the composer; the bot behind a username
/// is looked up once and remembered, so typing on stays cheap.
class InlineQuerySuggester extends ChangeNotifier {
  InlineQuerySuggester({
    required this.controller,
    this.delay = const Duration(milliseconds: 300),
  }) {
    controller.addListener(_changed);
  }

  final TextEditingController controller;

  /// The inline bot behind a username; null when there is none.
  Future<td.User?> Function(String username)? resolveBot;

  /// The bot's results to a query; [offset] asks for the next page.
  Future<td.InlineQueryResults> Function(
    int botUserId,
    String query,
    String offset,
  )?
  search;
  final Duration delay;

  /// `@username` then a space, then the query (possibly empty).
  static final _pattern = RegExp(
    r'^@([A-Za-z][A-Za-z0-9_]{2,31})\s(.*)$',
    dotAll: true,
  );

  final _bots = <String, td.User?>{};
  String? _text;
  String? _dismissed;
  td.User? _bot;
  var _active = false;
  var _loading = false;
  var _queryId = 0;
  var _nextOffset = '';
  List<td.InlineQueryResult> _results = const [];
  Timer? _debounce;
  var _generation = 0;
  var _disposed = false;

  /// Whether the draft addresses an inline bot, so the panel shows.
  bool get active => _active;

  /// Whether an answer is on its way.
  bool get loading => _loading;

  /// The bot the draft addresses while [active].
  td.User? get bot => _bot;

  /// The results shown now, in the bot's order.
  List<td.InlineQueryResult> get results => _results;

  /// The query id the results belong to, for sending one.
  int get queryId => _queryId;

  /// Whether the bot has more results than shown.
  bool get hasMore => _nextOffset.isNotEmpty;

  void _changed() {
    final match = search == null ? null : _pattern.firstMatch(controller.text);
    final text = match?.group(0);
    if (text == _text) return;
    _text = text;
    _debounce?.cancel();
    final generation = ++_generation;
    if (match == null || text == _dismissed) {
      _dismissed = match == null ? null : _dismissed;
      _clear();
      return;
    }
    _dismissed = null;
    final username = match.group(1)!;
    final query = match.group(2)!;
    _debounce = Timer(
      delay,
      () => unawaited(_ask(generation, username, query)),
    );
  }

  Future<void> _ask(int generation, String username, String query) async {
    td.User? bot;
    try {
      bot = _bots.containsKey(username)
          ? _bots[username]
          : _bots[username] = await resolveBot!(username);
    } on Object {
      return;
    }
    if (generation != _generation || _disposed) return;
    if (bot == null) {
      _clear();
      return;
    }
    _bot = bot;
    _active = true;
    _loading = true;
    _results = const [];
    _queryId = 0;
    _nextOffset = '';
    notifyListeners();
    final td.InlineQueryResults answer;
    try {
      answer = await search!(bot.id, query, '');
    } on Object {
      if (generation == _generation && !_disposed) {
        _loading = false;
        notifyListeners();
      }
      return;
    }
    if (generation != _generation || _disposed) return;
    _loading = false;
    _queryId = answer.inlineQueryId;
    _nextOffset = answer.nextOffset;
    _results = answer.results;
    notifyListeners();
  }

  /// Asks for the next page, when the bot has one and nothing is loading.
  Future<void> loadMore() async {
    final bot = _bot;
    final text = _text;
    if (bot == null || text == null || _loading || !hasMore) return;
    final generation = _generation;
    final query = _pattern.firstMatch(text)!.group(2)!;
    _loading = true;
    notifyListeners();
    final td.InlineQueryResults answer;
    try {
      answer = await search!(bot.id, query, _nextOffset);
    } on Object {
      if (generation == _generation && !_disposed) {
        _loading = false;
        _nextOffset = '';
        notifyListeners();
      }
      return;
    }
    if (generation != _generation || _disposed) return;
    _loading = false;
    _nextOffset = answer.nextOffset;
    _results = [..._results, ...answer.results];
    notifyListeners();
  }

  void _clear() {
    if (_disposed) return;
    final wasActive = _active;
    _active = false;
    _loading = false;
    _bot = null;
    _results = const [];
    _queryId = 0;
    _nextOffset = '';
    if (wasActive) notifyListeners();
  }

  /// Esc: hides the panel until the draft changes.
  void dismiss() {
    _dismissed = _text;
    _generation++;
    _debounce?.cancel();
    _clear();
  }

  /// Another chat: forgets what Esc dismissed and reads the draft again.
  void reset() {
    _dismissed = null;
    _text = null;
    _generation++;
    _debounce?.cancel();
    _clear();
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
