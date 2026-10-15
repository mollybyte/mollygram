import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// Watches the draft for a single emoji and looks up the stickers that
/// stand for it, for the strip above the composer.
class StickerSuggester extends ChangeNotifier {
  StickerSuggester({
    required this.controller,
    this.search,
    this.delay = const Duration(milliseconds: 150),
  }) {
    controller.addListener(_changed);
  }

  final TextEditingController controller;

  /// Stickers for an emoji.
  Future<List<td.Sticker>> Function(String emoji)? search;
  final Duration delay;

  List<td.Sticker> _stickers = const [];
  String? _emoji;
  String? _dismissed;
  Timer? _debounce;
  var _generation = 0;
  var _disposed = false;

  /// The stickers for the emoji in the draft; empty otherwise.
  List<td.Sticker> get stickers => _stickers;

  /// One emoji, possibly with a skin tone, a variation selector or a
  /// ZWJ sequence, and nothing else.
  static const _pictographic = r'\p{Extended_Pictographic}';
  static final _singleEmoji = RegExp(
    '^$_pictographic'
    '(?:[\\u{1F3FB}-\\u{1F3FF}]|\\u{FE0F}|\\u{200D}$_pictographic)*\$',
    unicode: true,
  );

  static String? emojiOf(String text) {
    final trimmed = text.trim();
    return _singleEmoji.hasMatch(trimmed) ? trimmed : null;
  }

  void _changed() {
    final emoji = search == null ? null : emojiOf(controller.text);
    if (emoji == _emoji) return;
    _emoji = emoji;
    _debounce?.cancel();
    final generation = ++_generation;
    if (emoji == null || emoji == _dismissed) {
      _dismissed = emoji == null ? null : _dismissed;
      _set(const []);
      return;
    }
    _dismissed = null;
    _debounce = Timer(delay, () async {
      final List<td.Sticker> found;
      try {
        found = await search!(emoji);
      } on Object {
        return;
      }
      if (generation == _generation) _set(found);
    });
  }

  void _set(List<td.Sticker> stickers) {
    if (_disposed) return;
    if (stickers.isEmpty && _stickers.isEmpty) return;
    _stickers = stickers;
    notifyListeners();
  }

  /// Hides the strip until the emoji changes.
  void dismiss() {
    _dismissed = _emoji;
    _generation++;
    _debounce?.cancel();
    _set(const []);
  }

  void reset() {
    _dismissed = null;
    _emoji = null;
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
