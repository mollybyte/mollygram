import 'package:mollygram_core/mollygram_core.dart';
import 'package:test/test.dart';

void main() {
  group('ChatListStore', () {
    test('sorts pinned chats, then TDLib order and chat id', () {
      final store = ChatListStore();
      const main = ChatListLocation.main();

      store.upsert(
        ChatListEntry(
          id: 1,
          title: 'Older',
          unreadCount: 0,
          positions: [
            ChatListPosition(list: main, order: 100, isPinned: false),
          ],
        ),
      );
      store.upsert(
        ChatListEntry(
          id: 2,
          title: 'Pinned',
          unreadCount: 0,
          positions: [ChatListPosition(list: main, order: 1, isPinned: true)],
        ),
      );
      store.upsert(
        ChatListEntry(
          id: 3,
          title: 'Newest',
          unreadCount: 0,
          positions: [
            ChatListPosition(list: main, order: 200, isPinned: false),
          ],
        ),
      );

      expect(store.chatsFor(main).map((chat) => chat.id), [2, 3, 1]);
    });

    test('updates one chat without discarding its other positions', () {
      final store = ChatListStore();
      const main = ChatListLocation.main();
      const work = ChatListLocation.folder(4);
      store.upsert(
        ChatListEntry(
          id: 1,
          title: 'Molly',
          unreadCount: 2,
          positions: [
            ChatListPosition(list: main, order: 10, isPinned: false),
            ChatListPosition(list: work, order: 20, isPinned: false),
          ],
        ),
      );

      store.updateTitle(1, 'Mollygram');
      store.updateUnreadCount(1, 7);
      store.updatePosition(
        1,
        const ChatListPosition(list: main, order: 30, isPinned: true),
      );

      final chat = store.chat(1)!;
      expect(chat.title, 'Mollygram');
      expect(chat.unreadCount, 7);
      expect(chat.positionFor(main)!.isPinned, isTrue);
      expect(chat.positionFor(work)!.order, 20);
    });

    test('removes a chat from a list when TDLib reports order zero', () {
      final store = ChatListStore();
      const main = ChatListLocation.main();
      store.upsert(
        ChatListEntry(
          id: 1,
          title: 'Molly',
          unreadCount: 0,
          positions: [ChatListPosition(list: main, order: 10, isPinned: false)],
        ),
      );

      store.updatePosition(
        1,
        const ChatListPosition(list: main, order: 0, isPinned: false),
      );

      expect(store.chatsFor(main), isEmpty);
      expect(store.chat(1), isNotNull);
    });

    test('keeps the server-defined folder order', () {
      final store = ChatListStore();

      store.replaceFolders(const [
        ChatFolder(id: 2, title: 'Work', iconName: 'Work'),
        ChatFolder(id: 1, title: 'Personal', iconName: 'Favorite'),
      ]);

      expect(store.folders.map((folder) => folder.id), [2, 1]);
    });

    test('replaces the last message and its positions together', () {
      final store = ChatListStore();
      const main = ChatListLocation.main();
      store.upsert(
        ChatListEntry(id: 1, title: 'Chat', unreadCount: 0, positions: []),
      );

      store.updateLastMessage(
        1,
        const ChatPreview(
          kind: ChatPreviewKind.photo,
          text: 'Caption',
          date: 5,
          isOutgoing: false,
        ),
        [ChatListPosition(list: main, order: 5, isPinned: false)],
      );

      final chat = store.chatsFor(main).single;
      expect(chat.lastMessage?.kind, ChatPreviewKind.photo);
      expect(chat.lastMessage?.text, 'Caption');

      store.updateLastMessage(1, null, const []);
      expect(store.chat(1)?.lastMessage, isNull);
      expect(store.chatsFor(main), isEmpty);
    });
  });
}
