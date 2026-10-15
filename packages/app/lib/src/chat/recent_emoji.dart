import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Where recently used emoji are kept between launches. Telegram has no
/// server list of them; the official apps keep them on the device too.
abstract interface class RecentEmojiStorage {
  Future<List<String>> read();

  Future<void> write(List<String> emoji);
}

final recentEmojiStorageProvider = Provider<RecentEmojiStorage>(
  (ref) => FileRecentEmojiStorage(),
);

/// `recent_emoji.json` in the app's support folder.
final class FileRecentEmojiStorage implements RecentEmojiStorage {
  Future<File> _file() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}${Platform.pathSeparator}recent_emoji.json');
  }

  @override
  Future<List<String>> read() async {
    try {
      final json = jsonDecode(await (await _file()).readAsString());
      return [
        for (final emoji in json as List<Object?>)
          if (emoji is String) emoji,
      ];
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> write(List<String> emoji) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(emoji), flush: true);
    await temp.rename(file.path);
  }
}

/// A [RecentEmojiStorage] in memory, for tests.
final class MemoryRecentEmojiStorage implements RecentEmojiStorage {
  MemoryRecentEmojiStorage([this.saved = const []]);

  List<String> saved;

  @override
  Future<List<String>> read() async => saved;

  @override
  Future<void> write(List<String> emoji) async => saved = emoji;
}

final recentEmojiProvider = NotifierProvider<RecentEmoji, List<String>>(
  RecentEmoji.new,
);

/// The emoji the user picked last, newest first.
class RecentEmoji extends Notifier<List<String>> {
  static const limit = 32;

  @override
  List<String> build() {
    final storage = ref.watch(recentEmojiStorageProvider);
    unawaited(
      storage.read().then((saved) {
        // A pick made while reading comes first.
        if (ref.mounted) state = _merge(state, saved);
      }),
    );
    return const [];
  }

  void use(String emoji) {
    state = _merge([emoji], state);
    unawaited(
      ref.read(recentEmojiStorageProvider).write(state).catchError((_) {}),
    );
  }

  static List<String> _merge(List<String> first, List<String> then) =>
      {...first, ...then}.take(limit).toList();
}
