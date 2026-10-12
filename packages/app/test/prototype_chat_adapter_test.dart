import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/prototype_chat_adapter.dart';
import 'package:mollygram_core/mollygram_core.dart';

void main() {
  test('maps TDLib list entries in TDLib order', () {
    final store = ChatListStore()
      ..upsert(
        ChatListEntry(
          id: 1,
          title: 'Anna Morris',
          unreadCount: 3,
          positions: const [
            ChatListPosition(
              list: ChatListLocation.main(),
              order: 1,
              isPinned: false,
            ),
          ],
        ),
      );

    final chats = PrototypeChatAdapter.chatsFor(
      store,
      const ChatListLocation.main(),
    );

    expect(chats.single.name, 'Anna Morris');
    expect(chats.single.initials, 'AM');
    expect(chats.single.unread, 3);
  });
}
