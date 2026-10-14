import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

import 'support/messages.dart';

void main() {
  test('deduplicates messages and keeps newest first', () {
    final store = ConversationStore();
    store.upsert(
      textMessage(id: 10, chatId: 1, text: 'Older', isOutgoing: false),
    );
    store.upsert(
      textMessage(id: 12, chatId: 1, text: 'Newest', isOutgoing: true),
    );
    store.upsert(
      textMessage(id: 10, chatId: 1, text: 'Edited locally', isOutgoing: false),
    );

    expect(store.messagesFor(1).map((message) => message.id), [12, 10]);
    expect(store.messagesFor(1).last.text, 'Edited locally');
  });

  test('replaces a chat history without touching another chat', () {
    final store = ConversationStore();
    store.upsert(
      textMessage(id: 1, chatId: 2, text: 'Keep', isOutgoing: false),
    );

    store.replaceHistory(1, [
      textMessage(id: 3, chatId: 1, text: 'History', isOutgoing: false),
    ]);

    expect(store.messagesFor(1).single.text, 'History');
    expect(store.messagesFor(2).single.text, 'Keep');
  });

  test('patches a single field and keeps the rest', () {
    final store = ConversationStore();
    store.upsert(textMessage(id: 5, chatId: 1, text: 'Hi'));

    expect(store.patch(1, 5, {'edit_date': 99}), isTrue);
    expect(store.patch(1, 6, {'edit_date': 99}), isFalse);
    expect(store.messagesFor(1).single.editDate, 99);
    expect(store.messagesFor(1).single.text, 'Hi');
  });

  test('adds older pages without duplicates and finds the oldest', () {
    final store = ConversationStore();
    store.replaceHistory(1, [textMessage(id: 9, chatId: 1, text: 'New')]);

    final added = store.addOlder(1, [
      textMessage(id: 9, chatId: 1, text: 'New'),
      textMessage(id: 4, chatId: 1, text: 'Old'),
    ]);

    expect(added, 1);
    expect(store.oldestId(1), 4);
    expect(store.messagesFor(1).map((m) => m.id), [9, 4]);
  });

  test('tells chat events from messages people wrote', () {
    expect(textMessage(id: 1, chatId: 1, text: 'x').isService, isFalse);
    expect(
      ConversationMessage(
        tdMessage(id: 2, chatId: 1, content: const td.MessageChatJoinByLink()),
      ).isService,
      isTrue,
    );
  });
}
