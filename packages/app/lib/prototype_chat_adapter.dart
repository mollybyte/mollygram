import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_prototype/chat/fake_data.dart';

/// Temporary presentation adapter while the prototype sidebar becomes a real
/// chat-list widget. It keeps TDLib types out of the rendering package.
final class PrototypeChatAdapter {
  static List<FakeChat> chatsFor(ChatListStore store, ChatListLocation list) =>
      [
        for (final chat in store.chatsFor(list))
          FakeChat(
            chat.title,
            _initials(chat.title),
            '',
            '',
            unread: chat.unreadCount,
          ),
      ];

  static String _initials(String title) {
    final words = title
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final initials = words.take(2).map((word) => word[0]).join();
    return initials.isEmpty ? '?' : initials.toUpperCase();
  }
}
