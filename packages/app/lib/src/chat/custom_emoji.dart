import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import '../session/providers.dart';

/// The stickers behind the custom emoji on screen, fetched in batches as
/// texts ask for them, so a message with ten of them costs one request.
final customEmojiProvider = Provider<CustomEmojiCache>((ref) {
  final cache = CustomEmojiCache(
    fetch: (ids) => ref
        .read(telegramSessionProvider)
        .requireValue
        .stickers
        .customEmoji(ids),
  );
  ref.onDispose(cache.dispose);
  return cache;
});

class CustomEmojiCache extends ChangeNotifier {
  CustomEmojiCache({required this.fetch});

  final Future<List<td.Sticker>> Function(List<int> ids) fetch;

  final _known = <int, td.Sticker?>{};
  final _pending = <int>{};
  var _scheduled = false;
  var _disposed = false;

  /// The sticker of custom emoji [id], or null while it loads or when
  /// Telegram knows no such emoji; listeners are told when it arrives.
  td.Sticker? lookup(int id) {
    if (_known.containsKey(id)) return _known[id];
    _pending.add(id);
    if (!_scheduled) {
      _scheduled = true;
      scheduleMicrotask(() => unawaited(_flush()));
    }
    return null;
  }

  Future<void> _flush() async {
    _scheduled = false;
    // TDLib takes up to 200 ids at a time.
    final ids = _pending.take(200).toList();
    _pending.removeAll(ids);
    if (_pending.isNotEmpty && !_scheduled) {
      _scheduled = true;
      scheduleMicrotask(() => unawaited(_flush()));
    }
    List<td.Sticker> stickers;
    try {
      stickers = await fetch(ids);
    } on Object {
      // Asked again on the next build.
      return;
    }
    if (_disposed) return;
    for (final id in ids) {
      _known[id] = null;
    }
    for (final sticker in stickers) {
      if (sticker.fullType case td.StickerFullTypeCustomEmoji(
        :final customEmojiId,
      )) {
        _known[customEmojiId] = sticker;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
