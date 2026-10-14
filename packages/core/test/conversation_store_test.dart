import 'package:mollygram_core/mollygram_core.dart';
import 'package:test/test.dart';

void main() {
  test('deduplicates messages and keeps newest first', () {
    final store = ConversationStore();
    store.upsert(
      const ConversationMessage(
        id: 10,
        chatId: 1,
        text: 'Older',
        date: 10,
        isOutgoing: false,
      ),
    );
    store.upsert(
      const ConversationMessage(
        id: 12,
        chatId: 1,
        text: 'Newest',
        date: 12,
        isOutgoing: true,
      ),
    );
    store.upsert(
      const ConversationMessage(
        id: 10,
        chatId: 1,
        text: 'Edited locally',
        date: 10,
        isOutgoing: false,
      ),
    );

    expect(store.messagesFor(1).map((message) => message.id), [12, 10]);
    expect(store.messagesFor(1).last.text, 'Edited locally');
  });

  test('replaces a chat history without touching another chat', () {
    final store = ConversationStore();
    store.upsert(
      const ConversationMessage(
        id: 1,
        chatId: 2,
        text: 'Keep',
        date: 1,
        isOutgoing: false,
      ),
    );

    store.replaceHistory(1, const [
      ConversationMessage(
        id: 3,
        chatId: 1,
        text: 'History',
        date: 3,
        isOutgoing: false,
      ),
    ]);

    expect(store.messagesFor(1).single.text, 'History');
    expect(store.messagesFor(2).single.text, 'Keep');
  });
}
