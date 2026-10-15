import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final now = DateTime.fromMillisecondsSinceEpoch(1700000500000);
  late FakeTdJson json;
  late td.Td tdlib;
  late td.TdClient client;
  late MessageStore store;
  late MessageCapture capture;
  var opened = 0;

  setUp(() async {
    json = FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    client = tdlib.createClient();
    store = await MessageStore.memory();
    opened = 0;
    capture = MessageCapture(
      client,
      openStore: () async {
        opened++;
        return store;
      },
      keepDeleted: true,
      keepEdits: true,
      now: () => now,
      messagesPerChat: 3,
    );
  });

  tearDown(() async {
    await capture.dispose();
    await tdlib.close();
  });

  Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await capture.flush();
  }

  void newMessage(
    int chatId,
    int id,
    String text, {
    bool selfDestruct = false,
  }) => json.push({
    '@type': 'updateNewMessage',
    'message': messageJson(chatId, id, text, selfDestruct: selfDestruct),
  });

  void delete(
    int chatId,
    List<int> ids, {
    bool permanent = true,
    bool fromCache = false,
  }) => json.push({
    '@type': 'updateDeleteMessages',
    'chat_id': chatId,
    'message_ids': ids,
    'is_permanent': permanent,
    'from_cache': fromCache,
  });

  Future<List<int>> keptIds(int chatId) async => [
    for (final m in await store.deleted.forChat(chatId)) m.messageId,
  ];

  group('deleted messages', () {
    test('keeps a seen message deleted for everyone', () async {
      newMessage(7, 1, 'hello');
      await settle();
      delete(7, [1]);
      await settle();

      final kept = await store.deleted.forChat(7);
      expect(kept.single.messageId, 1);
      expect(textOf(kept.single.message.content), 'hello');
      expect(kept.single.deletedAt, now);
      expect(capture.recent(7, 1), isNull);
    });

    test('keeps messages loaded by any request', () async {
      json.answers['getChatHistory'] = {
        '@type': 'messages',
        'total_count': 2,
        'messages': [messageJson(7, 4, 'four'), messageJson(7, 5, 'five')],
      };
      await client.send(
        const td.GetChatHistory(
          chatId: 7,
          fromMessageId: 0,
          offset: 0,
          limit: 2,
          onlyLocal: false,
        ),
      );
      delete(7, [4, 5]);
      await settle();

      expect(await keptIds(7), [4, 5]);
    });

    test('keeps nothing it never saw, or what TDLib only drops from its '
        'cache', () async {
      newMessage(7, 1, 'a');
      newMessage(7, 2, 'b');
      await settle();
      delete(7, [1], fromCache: true);
      delete(7, [2], permanent: false);
      delete(7, [3]);
      await settle();

      expect(await keptIds(7), isEmpty);
      expect(opened, 0);
    });

    test('keeps nothing deleted from this app', () async {
      newMessage(7, 1, 'a');
      newMessage(8, 1, 'b');
      await settle();
      await client.send(
        const td.DeleteMessages(chatId: 7, messageIds: [1], revoke: true),
      );
      await client.send(
        const td.DeleteChatHistory(
          chatId: 8,
          removeFromChatList: false,
          revoke: true,
        ),
      );
      delete(7, [1]);
      delete(8, [1]);
      await settle();

      expect(await keptIds(7), isEmpty);
      expect(await keptIds(8), isEmpty);
    });

    test('keeps no self-destructing message', () async {
      newMessage(7, 1, 'a', selfDestruct: true);
      await settle();
      delete(7, [1]);
      await settle();

      expect(await keptIds(7), isEmpty);
    });

    test('keeps nothing while the switch is off', () async {
      capture.keepDeleted = false;
      newMessage(7, 1, 'a');
      await settle();
      delete(7, [1]);
      await settle();

      expect(await keptIds(7), isEmpty);
      expect(opened, 0);
    });

    test('remembers only the newest messages of a chat', () async {
      for (var id = 1; id <= 4; id++) {
        newMessage(7, id, '$id');
      }
      await settle();
      delete(7, [1, 2, 3, 4]);
      await settle();

      expect(await keptIds(7), [2, 3, 4]);
    });

    test('follows a sent message to its new id', () async {
      newMessage(7, 100, 'sending');
      json.push({
        '@type': 'updateMessageSendSucceeded',
        'message': messageJson(7, 5, 'sending'),
        'old_message_id': 100,
      });
      await settle();

      expect(capture.recent(7, 100), isNull);
      expect(capture.recent(7, 5), isNotNull);
    });
  });

  group('edit history', () {
    void edit(int chatId, int id, String text, int editDate) {
      json
        ..push({
          '@type': 'updateMessageContent',
          'chat_id': chatId,
          'message_id': id,
          'new_content': textContent(text),
        })
        ..push({
          '@type': 'updateMessageEdited',
          'chat_id': chatId,
          'message_id': id,
          'edit_date': editDate,
        });
    }

    test('keeps each version an edit replaced', () async {
      newMessage(7, 1, 'first');
      await settle();
      edit(7, 1, 'second', 1700000100);
      edit(7, 1, 'third', 1700000200);
      await settle();

      final versions = await store.edits.versions(7, 1);
      expect(
        [for (final v in versions) textOf(v.content)],
        ['first', 'second'],
      );
      expect(versions.first.date.millisecondsSinceEpoch, 1700000000000);
      expect(versions.first.replacedAt.millisecondsSinceEpoch, 1700000100000);
      expect(versions.last.date.millisecondsSinceEpoch, 1700000100000);
      expect(textOf(capture.recent(7, 1)!.content), 'third');
    });

    test('a content change that is not an edit is not kept', () async {
      newMessage(7, 1, 'poll');
      await settle();
      json.push({
        '@type': 'updateMessageContent',
        'chat_id': 7,
        'message_id': 1,
        'new_content': textContent('votes changed'),
      });
      await settle();

      expect(await store.edits.versions(7, 1), isEmpty);
      expect(opened, 0);
    });

    test('keeps nothing while the switch is off', () async {
      capture.keepEdits = false;
      newMessage(7, 1, 'first');
      await settle();
      edit(7, 1, 'second', 1700000100);
      await settle();

      expect(await store.edits.versions(7, 1), isEmpty);
    });
  });

  test('the store opens once, on first use', () async {
    newMessage(7, 1, 'a');
    newMessage(7, 2, 'b');
    await settle();
    delete(7, [1, 2]);
    await settle();

    expect(opened, 1);
  });
}
