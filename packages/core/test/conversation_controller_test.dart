import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

import 'support/messages.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late ConversationController controller;

  setUp(() {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    controller = ConversationController(tdlib.createClient());
  });

  tearDown(() async {
    await controller.dispose();
    await tdlib.close();
  });

  test('loads text history and applies new-message updates', () async {
    await controller.start();
    await controller.loadHistory(7);

    expect(controller.store.messagesFor(7).map((message) => message.text), [
      'From history',
    ]);

    json.push({
      '@type': 'updateNewMessage',
      'message': _message(id: 11, chatId: 7, text: 'Live').toJson(),
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(controller.store.messagesFor(7).map((message) => message.text), [
      'Live',
      'From history',
    ]);
  });

  test(
    'sends plain text through TDLib and adds the response to the timeline',
    () async {
      await controller.start();

      await controller.sendText(7, 'Sent text');

      final request = json.sent.single;
      expect(request['@type'], 'sendMessage');
      expect(request['chat_id'], 7);
      expect(
        (request['input_message_content'] as Map<String, Object?>)['text'],
        {
          '@type': 'formattedText',
          'text': 'Sent text',
          'entities': <Object?>[],
        },
      );
      expect(controller.store.messagesFor(7).single.text, 'Sent text');
    },
  );

  test('replaces the pending copy once the server confirms a send', () async {
    await controller.start();
    await controller.sendText(7, 'Sent text');

    json.push({
      '@type': 'updateMessageSendSucceeded',
      'message': _message(id: 40, chatId: 7, text: 'Sent text').toJson(),
      'old_message_id': 12,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(controller.store.messagesFor(7).map((message) => message.id), [40]);
    // The timeline keeps the row under the temporary id, so it is not
    // redrawn when the server one arrives, nor when the message changes.
    expect(controller.store.messagesFor(7).single.keyId, 12);
    json.push({
      '@type': 'updateMessageInteractionInfo',
      'chat_id': 7,
      'message_id': 40,
      'interaction_info': null,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.messagesFor(7).single.keyId, 12);
  });

  test('applies edits and permanent deletions', () async {
    await controller.start();
    await controller.loadHistory(7);

    json.push({
      '@type': 'updateMessageContent',
      'chat_id': 7,
      'message_id': 10,
      'new_content': td.MessageText(
        text: td.FormattedText(text: 'Edited', entities: const []),
      ).toJson(),
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.messagesFor(7).single.text, 'Edited');

    json.push({
      '@type': 'updateDeleteMessages',
      'chat_id': 7,
      'message_ids': [10],
      'is_permanent': true,
      'from_cache': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.messagesFor(7), isEmpty);
  });

  test('hides messages that became inaccessible', () async {
    await controller.start();
    await controller.loadHistory(7);

    json.push({
      '@type': 'updateDeleteMessages',
      'chat_id': 7,
      'message_ids': [10],
      'is_permanent': false,
      'from_cache': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.messagesFor(7), isEmpty);
  });

  test('keeps messages TDLib only evicted from its cache', () async {
    await controller.start();
    await controller.loadHistory(7);

    json.push({
      '@type': 'updateDeleteMessages',
      'chat_id': 7,
      'message_ids': [10],
      'is_permanent': false,
      'from_cache': true,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.messagesFor(7).single.id, 10);
  });

  test('keeps a message that arrived while history was loading', () async {
    json.liveDuringHistory = _message(id: 11, chatId: 7, text: 'Live');
    await controller.start();

    await controller.loadHistory(7);

    expect(controller.store.messagesFor(7).map((message) => message.id), [
      11,
      10,
    ]);
  });

  test('marks a message the server rejected as failed', () async {
    await controller.start();
    await controller.sendText(7, 'Sent text');
    expect(
      controller.store.messagesFor(7).single.sendState,
      MessageSendState.pending,
    );

    json.push({
      '@type': 'updateMessageSendFailed',
      'message': _message(
        id: 13,
        chatId: 7,
        text: 'Sent text',
        sendingState: const td.MessageSendingStateFailed(
          error: td.TdError(code: 403, message: 'CHAT_WRITE_FORBIDDEN'),
          canRetry: false,
          needAnotherSender: false,
          needAnotherReplyQuote: false,
          needDropReply: false,
          requiredPaidMessageStarCount: 0,
          retryAfter: 0,
        ),
      ).toJson(),
      'old_message_id': 12,
      'error': {
        '@type': 'error',
        'code': 403,
        'message': 'CHAT_WRITE_FORBIDDEN',
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final message = controller.store.messagesFor(7).single;
    expect(message.id, 13);
    expect(message.sendState, MessageSendState.failed);
  });

  test('loads older pages until the screen is filled', () async {
    // TDLib answers the first request with just the last message.
    json.history = (from) => from == 0
        ? [_message(id: 100, chatId: 7, text: 'Last')]
        : [
            for (var id = from - 1; id > from - 21 && id > 50; id--)
              _message(id: id, chatId: 7, text: '#$id'),
          ];
    await controller.start();

    await controller.loadHistory(7);

    final ids = controller.store.messagesFor(7).map((m) => m.id);
    expect(ids.length, greaterThanOrEqualTo(30));
    expect(ids.first, 100);

    // Paging to the start stops once a page adds nothing.
    while (await controller.loadOlder(7)) {}
    expect(controller.store.reachedStart(7), isTrue);
    expect(controller.store.oldestId(7), 51);
  });

  test('keeps media messages and their content updates', () async {
    await controller.start();
    await controller.loadHistory(7);

    json.push({
      '@type': 'updateMessageContent',
      'chat_id': 7,
      'message_id': 10,
      'new_content': {
        '@type': 'messageSticker',
        'is_premium': false,
        'sticker': {
          '@type': 'sticker',
          'id': '1',
          'set_id': '2',
          'width': 512,
          'height': 512,
          'emoji': '🙂',
          'format': {'@type': 'stickerFormatWebp'},
          'full_type': {'@type': 'stickerFullTypeRegular'},
          'sticker': {
            '@type': 'file',
            'id': 5,
            'size': 100,
            'expected_size': 100,
            'local': {
              '@type': 'localFile',
              'path': '',
              'can_be_downloaded': true,
              'can_be_deleted': false,
              'is_downloading_active': false,
              'is_downloading_completed': false,
              'download_offset': 0,
              'downloaded_prefix_size': 0,
              'downloaded_size': 0,
            },
            'remote': {
              '@type': 'remoteFile',
              'id': 'x',
              'unique_id': 'y',
              'is_uploading_active': false,
              'is_uploading_completed': true,
              'uploaded_size': 100,
            },
          },
        },
      },
    });
    json.push({
      '@type': 'updateMessageEdited',
      'chat_id': 7,
      'message_id': 10,
      'edit_date': 77,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final message = controller.store.messagesFor(7).single;
    expect(message.content, isA<td.MessageSticker>());
    expect(message.editDate, 77);
  });

  test('fetches a replied-to message outside the timeline once', () async {
    await controller.start();

    await controller.loadReplied(7, 10);
    await controller.loadReplied(7, 10);

    expect(
      json.sent.where((r) => r['@type'] == 'getRepliedMessage'),
      hasLength(1),
    );
    expect(controller.store.message(7, 3)?.text, 'Quoted');
  });

  test('quotes part of the original in a reply', () async {
    await controller.start();

    await controller.sendText(
      7,
      'Agreed',
      replyTo: 10,
      quote: 'the big one',
      quotePosition: 17,
    );

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final replyTo = send['reply_to']! as Map;
    expect(replyTo['message_id'], 10);
    final quote = replyTo['quote']! as Map;
    expect((quote['text']! as Map)['text'], 'the big one');
    expect(quote['position'], 17);

    await controller.sendText(7, 'Plain', replyTo: 10);
    final plain = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect((plain['reply_to']! as Map)['quote'], isNull);
  });

  test('asks who saw a message, who reacted and when it was read', () async {
    await controller.start();

    final viewers = await controller.viewers(7, 10);
    expect(viewers.single.userId, 3);
    final added = await controller.addedReactions(7, 10);
    expect(added.single.senderId, isA<td.MessageSenderUser>());
    final read = await controller.readDate(7, 10);
    expect(read, isA<td.MessageReadDateRead>());
    expect(
      json.sent
          .map((r) => r['@type'])
          .where(
            (t) =>
                t == 'getMessageViewers' ||
                t == 'getMessageAddedReactions' ||
                t == 'getMessageReadDate',
          ),
      hasLength(3),
    );
  });

  test('lists every emoji reaction once for the full picker', () async {
    await controller.start();

    final all = await controller.allReactions(7, 10);
    final request = json.sent.lastWhere(
      (r) => r['@type'] == 'getMessageAvailableReactions',
    );
    expect(request['row_size'], 25);
    expect(all, all.toSet().toList());
    expect(all, containsAll(await controller.quickReactions(7, 10)));
  });

  test('tells when a member may not write and how slowmode holds', () async {
    await controller.start();
    json.push(
      _chat(
        lastRead: 0,
        unread: 0,
        last: 8,
        type: {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 99,
          'is_channel': false,
        },
        canSendText: false,
      ),
    );
    json.push(
      _supergroup(99, {
        '@type': 'chatMemberStatusMember',
        'member_since_date': 0,
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final store = controller.store;
    expect(store.canPost(7), isTrue);
    expect(store.canSendText(7), isFalse);
    expect(store.restrictedUntil(7), isNull);

    // The group lets people write again, but this user is restricted.
    json.push({
      '@type': 'updateChatPermissions',
      'chat_id': 7,
      'permissions': {
        '@type': 'chatPermissions',
        'can_send_basic_messages': true,
      },
    });
    json.push(
      _supergroup(99, {
        '@type': 'chatMemberStatusRestricted',
        'is_member': true,
        'restricted_until_date': 1800000000,
        'permissions': {'@type': 'chatPermissions'},
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(store.canSendText(7), isFalse);
    expect(store.restrictedUntil(7), 1800000000);

    // An admin writes whatever the group says.
    json.push(
      _supergroup(99, {
        '@type': 'chatMemberStatusAdministrator',
        'can_be_edited': false,
        'rights': {'@type': 'chatAdministratorRights'},
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(store.canSendText(7), isTrue);

    json.push(
      _supergroup(99, {
        '@type': 'chatMemberStatusMember',
        'member_since_date': 0,
      }),
    );
    json.push({
      '@type': 'updateSupergroupFullInfo',
      'supergroup_id': 99,
      'supergroup_full_info': {
        '@type': 'supergroupFullInfo',
        'slow_mode_delay': 30,
        'slow_mode_delay_expires_in': 12.5,
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(store.canSendText(7), isTrue);
    expect(store.slowModeDelay(7), 30);
    expect(store.slowModeUntil(7), isNotNull);

    controller.noteSlowModeWait(7, 0);
    expect(store.slowModeUntil(7), isNull);
    controller.noteSlowModeWait(7, 20);
    expect(store.slowModeUntil(7), isNotNull);
  });

  test('keeps the server draft and saves the user\'s own', () async {
    await controller.start();
    json.push({
      '@type': 'updateChatDraftMessage',
      'chat_id': 7,
      'draft_message': {
        '@type': 'draftMessage',
        'date': 1700000000,
        'content': {
          '@type': 'draftMessageContentText',
          'text': {
            '@type': 'formattedText',
            'text': 'Unsent',
            'entities': <Object?>[],
          },
        },
        'effect_id': 0,
      },
      'positions': <Object?>[],
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final store = controller.store;
    expect(
      (store.draft(7)!.content as td.DraftMessageContentText).text.text,
      'Unsent',
    );

    await controller.saveDraft(
      7,
      text: const td.FormattedText(text: 'Hi there', entities: []),
      replyTo: 10,
    );
    var sent = json.sent.last;
    expect(sent['@type'], 'setChatDraftMessage');
    final draft = sent['draft_message']! as Map;
    expect(((draft['content']! as Map)['text']! as Map)['text'], 'Hi there');
    expect((draft['reply_to']! as Map)['message_id'], 10);

    // The same draft again is not sent twice.
    final before = json.sent.length;
    await controller.saveDraft(
      7,
      text: const td.FormattedText(text: 'Hi there', entities: []),
      replyTo: 10,
    );
    expect(json.sent.length, before);

    await controller.saveDraft(7);
    sent = json.sent.last;
    expect(sent['@type'], 'setChatDraftMessage');
    expect(sent.containsKey('draft_message'), isFalse);
    expect(store.draft(7), isNull);
  });

  test('previews the link in a draft and sends how it should show', () async {
    await controller.start();

    final none = await controller.linkPreview(
      const td.FormattedText(text: 'Plain words', entities: []),
    );
    expect(none, isNull);

    final preview = await controller.linkPreview(
      const td.FormattedText(text: 'See https://example.com/a', entities: []),
    );
    expect(preview?.title, 'An example page');
    expect(json.sent.last['@type'], 'getLinkPreview');

    await controller.sendText(
      7,
      'See https://example.com/a',
      linkPreviewOptions: const td.LinkPreviewOptions(
        isDisabled: false,
        url: 'https://example.com/a',
        forceSmallMedia: false,
        forceLargeMedia: false,
        showAboveText: true,
      ),
    );
    final sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final options =
        (sent['input_message_content']! as Map)['link_preview_options']! as Map;
    expect(options['show_above_text'], isTrue);
    expect(options['url'], 'https://example.com/a');

    // A draft that drops its preview differs from one that keeps it.
    await controller.saveDraft(
      7,
      text: const td.FormattedText(
        text: 'See https://example.com/a',
        entities: [],
      ),
    );
    final before = json.sent.length;
    await controller.saveDraft(
      7,
      text: const td.FormattedText(
        text: 'See https://example.com/a',
        entities: [],
      ),
      linkPreviewOptions: const td.LinkPreviewOptions(
        isDisabled: true,
        url: '',
        forceSmallMedia: false,
        forceLargeMedia: false,
        showAboveText: false,
      ),
    );
    expect(json.sent.length, before + 1);
    final draft = json.sent.last['draft_message']! as Map;
    expect(
      ((draft['content']! as Map)['link_preview_options']!
          as Map)['is_disabled'],
      isTrue,
    );
  });

  test(
    'sends without sound or at a time, keeping the scheduled one out',
    () async {
      await controller.start();

      await controller.sendText(7, 'Quiet', silent: true);
      var sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
      expect((sent['options']! as Map)['disable_notification'], isTrue);
      expect(
        (sent['options']! as Map).containsKey('scheduling_state'),
        isFalse,
      );
      expect(controller.store.messagesFor(7).map((m) => m.text), ['Sent text']);

      await controller.sendText(
        7,
        'Later',
        schedule: const td.MessageSchedulingStateSendAtDate(
          sendDate: 1800000000,
          repeatPeriod: 0,
        ),
      );
      sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
      final state = (sent['options']! as Map)['scheduling_state']! as Map;
      expect(state['send_date'], 1800000000);
      // It waits in the scheduled list, so the timeline gained nothing.
      expect(controller.store.messagesFor(7).length, 1);

      await controller.sendText(7, 'Plain');
      sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
      expect(sent.containsKey('options'), isFalse);
    },
  );

  test('follows and manages the scheduled messages of a chat', () async {
    await controller.start();
    final store = controller.store;
    expect(store.hasScheduledMessages(7), isFalse);

    json.push({
      '@type': 'updateChatHasScheduledMessages',
      'chat_id': 7,
      'has_scheduled_messages': true,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(store.hasScheduledMessages(7), isTrue);
    final version = store.scheduledVersion(7);

    final scheduled = await controller.scheduledMessages(7);
    expect(scheduled.map((m) => m.text), ['First', 'Second']);

    await controller.sendScheduledNow(7, 30);
    var sent = json.sent.last;
    expect(sent['@type'], 'editMessageSchedulingState');
    expect(sent['message_id'], 30);
    expect(sent.containsKey('scheduling_state'), isFalse);

    await controller.reschedule(7, 31, DateTime.utc(2030, 1, 1));
    sent = json.sent.last;
    expect(
      (sent['scheduling_state']! as Map)['send_date'],
      DateTime.utc(2030, 1, 1).millisecondsSinceEpoch ~/ 1000,
    );

    await controller.deleteScheduled(7, [31]);
    sent = json.sent.last;
    expect(sent['@type'], 'deleteMessages');
    expect(sent['revoke'], isTrue);
    // Each change counts, so a view knows to load the list again.
    expect(store.scheduledVersion(7), greaterThan(version));
  });

  test('reports messages step by step as the server asks', () async {
    await controller.start();

    final first = await controller.report(7, [10]);
    final options = (first as td.ReportChatResultOptionRequired).options;
    expect(options.map((o) => o.text), ['Spam', 'Violence']);
    var sent = json.sent.last;
    expect(sent['@type'], 'reportChat');
    expect(sent['option_id'], '');
    expect(sent['message_ids'], [10]);

    final second = await controller.report(7, [10], optionId: options[0].id);
    expect(second, isA<td.ReportChatResultTextRequired>());
    sent = json.sent.last;
    expect(sent['option_id'], 'AQ==');

    final third = await controller.report(
      7,
      [10],
      optionId: options[0].id,
      text: 'Adverts',
    );
    expect(third, isA<td.ReportChatResultOk>());
    expect(json.sent.last['text'], 'Adverts');
  });

  test('unpins every message of a chat', () async {
    await controller.start();
    controller.store.setPinned(7, [30, 20]);

    await controller.unpinAll(7);

    expect(json.sent.last, containsPair('@type', 'unpinAllChatMessages'));
    expect(json.sent.last['chat_id'], 7);
    expect(controller.store.pinnedIds(7), isEmpty);
  });

  test('finds the last message of a day, or nothing before the chat', () async {
    await controller.start();

    final found = await controller.messageByDate(7, DateTime(2025, 10, 9, 15));
    expect(found?.id, 10);
    final request = json.sent.lastWhere(
      (r) => r['@type'] == 'getChatMessageByDate',
    );
    expect(request['chat_id'], 7);
    // The last second of the day: TDLib looks back from the date given.
    expect(
      request['date'],
      DateTime(2025, 10, 10).millisecondsSinceEpoch ~/ 1000 - 1,
    );

    json.byDateError = 404;
    expect(await controller.messageByDate(7, DateTime(2020)), isNull);
    json.byDateError = 500;
    expect(
      () => controller.messageByDate(7, DateTime(2020)),
      throwsA(isA<td.TdException>()),
    );
  });

  test('marks a reply as missing only when TDLib has no original', () async {
    await controller.start();

    json.repliedError = 500;
    await controller.loadReplied(7, 10);
    expect(controller.store.isMissing(7, 10), isFalse);

    json.repliedError = 404;
    await controller.loadReplied(7, 10);
    expect(controller.store.isMissing(7, 10), isTrue);
    expect(
      json.sent.where((r) => r['@type'] == 'getRepliedMessage'),
      hasLength(2),
    );
  });

  test('sends a reply to the chosen message', () async {
    await controller.start();

    await controller.sendText(7, 'Sure', replyTo: 10);

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(send['reply_to'], containsPair('message_id', 10));
    expect(
      send['reply_to'],
      containsPair('@type', 'inputMessageReplyToMessage'),
    );
  });

  test('sends and edits with the formatting the composer gives', () async {
    await controller.start();
    controller.store.replaceHistory(7, [
      ConversationMessage(tdMessage(id: 1, chatId: 7, text: 'Hi')),
    ]);
    const bold = td.TextEntity(
      offset: 0,
      length: 2,
      type: td.TextEntityTypeBold(),
    );

    await controller.sendText(7, 'Hi there', entities: const [bold]);
    await controller.editText(7, 1, 'Hi', entities: const [bold]);

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final sent = (send['input_message_content']! as Map)['text']! as Map;
    expect((sent['entities']! as List).single, bold.toJson());
    final edit = json.sent.lastWhere((r) => r['@type'] == 'editMessageText');
    final edited = (edit['input_message_content']! as Map)['text']! as Map;
    expect((edited['entities']! as List).single, bold.toJson());
  });

  test('edits text messages and captions with the right request', () async {
    await controller.start();
    controller.store.replaceHistory(7, [
      ConversationMessage(tdMessage(id: 1, chatId: 7, text: 'Hi')),
      ConversationMessage(
        tdMessage(
          id: 2,
          chatId: 7,
          content: td.MessagePhoto(
            photo: const td.Photo(hasStickers: false, sizes: []),
            caption: const td.FormattedText(text: 'Sea', entities: []),
            showCaptionAboveMedia: false,
            hasSpoiler: false,
            isSecret: false,
          ),
        ),
      ),
    ]);

    await controller.editText(7, 1, 'Hello');
    await controller.editText(7, 2, 'Sea view');

    expect(
      json.sent.map((r) => r['@type']),
      containsAllInOrder(['editMessageText', 'editMessageCaption']),
    );
    final caption = json.sent.last['caption']! as Map;
    expect(caption['text'], 'Sea view');
  });

  test('deletes and forwards through TDLib', () async {
    await controller.start();

    await controller.deleteMessages(7, [1, 2], revoke: true);
    await controller.deleteMessages(7, [], revoke: true);
    await controller.forwardMessages(8, 7, [3]);

    final types = json.sent.map((r) => r['@type']).toList();
    expect(types.where((t) => t == 'deleteMessages'), hasLength(1));
    final delete = json.sent.firstWhere((r) => r['@type'] == 'deleteMessages');
    expect(delete['message_ids'], [1, 2]);
    expect(delete['revoke'], isTrue);
    final forward = json.sent.firstWhere(
      (r) => r['@type'] == 'forwardMessages',
    );
    expect(forward['chat_id'], 8);
    expect(forward['from_chat_id'], 7);
    expect(forward['send_copy'], isFalse);

    // Without the senders' names the messages go as copies; captions can
    // only be dropped then.
    await controller.forwardMessages(8, 7, [3], hideCaptions: true);
    expect(json.sent.last['send_copy'], isFalse);
    expect(json.sent.last['remove_caption'], isFalse);
    await controller.forwardMessages(
      8,
      7,
      [3],
      hideSender: true,
      hideCaptions: true,
    );
    expect(json.sent.last['send_copy'], isTrue);
    expect(json.sent.last['remove_caption'], isTrue);
  });

  test('sends files as albums with the caption on the first', () async {
    await controller.start();

    await controller.sendFiles(
      7,
      const [
        OutgoingFile(path: '/a.jpg', kind: OutgoingKind.photo),
        OutgoingFile(path: '/b.mp4', kind: OutgoingKind.video),
        OutgoingFile(path: '/c.pdf', kind: OutgoingKind.document),
      ],
      caption: 'Trip',
      captionEntities: const [_italic],
      replyTo: 10,
    );

    final album = json.sent.firstWhere((r) => r['@type'] == 'sendMessageAlbum');
    final contents = album['input_message_contents']! as List;
    expect(contents, hasLength(2));
    final caption = (contents[0] as Map)['caption']! as Map;
    expect(caption['text'], 'Trip');
    expect((caption['entities']! as List).single, _italic.toJson());
    expect((contents[1] as Map)['caption'], isNull);
    expect(album['reply_to'], containsPair('message_id', 10));

    final single = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(
      (single['input_message_content']! as Map)['@type'],
      'inputMessageDocument',
    );
    expect(single['reply_to'], isNull);
    expect(controller.store.message(7, 30), isNotNull);
  });

  test('sends a sticker by its file id', () async {
    await controller.start();
    final sticker = td.Sticker.fromJson({
      '@type': 'sticker',
      'id': 100,
      'set_id': 55,
      'width': 512,
      'height': 480,
      'emoji': '🐱',
      'format': {'@type': 'stickerFormatWebp'},
      'full_type': {'@type': 'stickerFullTypeRegular'},
      'sticker': {
        '@type': 'file',
        'id': 301,
        'size': 1000,
        'expected_size': 1000,
        'local': {
          '@type': 'localFile',
          'path': '',
          'can_be_downloaded': true,
          'is_downloading_completed': false,
        },
        'remote': {'@type': 'remoteFile', 'id': 'r301', 'unique_id': 'u301'},
      },
    });

    await controller.sendSticker(7, sticker, replyTo: 10);

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(send['reply_to'], containsPair('message_id', 10));
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageSticker');
    expect(content['emoji'], '🐱');
    expect(content['sticker'], {
      '@type': 'inputSticker',
      'sticker': {'@type': 'inputFileId', 'id': 301},
      'width': 512,
      'height': 480,
    });
  });

  test('sends a video message with its side', () async {
    await controller.start();

    await controller.sendVideoNote(
      7,
      path: '/tmp/circle.mp4',
      duration: const Duration(milliseconds: 5100),
      side: 640,
    );

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageVideoNote');
    expect(content['video_note'], {
      '@type': 'inputVideoNote',
      'video_note': {'@type': 'inputFileLocal', 'path': '/tmp/circle.mp4'},
      'duration': 6,
      'length': 640,
    });
  });

  test('sends a voice message with its waveform', () async {
    await controller.start();

    await controller.sendVoiceNote(
      7,
      path: '/tmp/voice.ogg',
      duration: const Duration(milliseconds: 2400),
      waveform: Uint8List.fromList([1, 2, 3]),
      replyTo: 10,
    );

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(send['reply_to'], containsPair('message_id', 10));
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageVoiceNote');
    expect(content['voice_note'], {
      '@type': 'inputVoiceNote',
      'voice_note': {'@type': 'inputFileLocal', 'path': '/tmp/voice.ogg'},
      'duration': 3,
      'waveform': base64Encode([1, 2, 3]),
    });
  });

  test('opens a chat with unread messages at the last read one', () async {
    json.chat = [for (var id = 1; id <= 200; id++) id];
    await controller.start();
    json.push(_chat(lastRead: 100, unread: 100, last: 200));
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await controller.loadHistory(7);

    final request = json.sent.firstWhere((r) => r['@type'] == 'getChatHistory');
    expect(request['from_message_id'], 100);
    expect(request['offset'], -40);
    final ids = controller.store.messagesFor(7).map((m) => m.id);
    expect(ids.first, 140);
    expect(ids.last, 91);
    expect(controller.store.reachedEnd(7), isFalse);
    expect(controller.store.unreadCount(7), 100);
  });

  test('pages newer history up to the last message', () async {
    json.chat = [for (var id = 1; id <= 120; id++) id];
    await controller.start();
    json.push(_chat(lastRead: 0, unread: 0, last: 120));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await controller.loadAround(7, 50);
    expect(controller.store.newestId(7), 75);

    // A message beyond the gap waits for its page.
    json.push({
      '@type': 'updateNewMessage',
      'message': _message(id: 121, chatId: 7, text: 'Live').toJson(),
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.contains(7, 121), isFalse);

    expect(await controller.loadNewer(7), isTrue);
    expect(controller.store.newestId(7), 120);
    expect(controller.store.reachedEnd(7), isTrue);
    expect(await controller.loadNewer(7), isFalse);
  });

  test('keeps unread mention and reaction counts', () async {
    await controller.start();
    json
      ..push(_chat(lastRead: 5, unread: 3, last: 8, mentions: 2, reactions: 1))
      ..push({
        '@type': 'updateMessageMentionRead',
        'chat_id': 7,
        'message_id': 6,
        'unread_mention_count': 1,
      });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.unreadMentionCount(7), 1);
    expect(controller.store.unreadReactionCount(7), 1);

    final mention = await controller.firstUnread(7);
    expect(mention?.id, 30);
  });

  test('keeps the bot keyboard of a chat and asks a bot button', () async {
    await controller.start();
    expect(controller.store.replyMarkupMessageId(7), 0);

    json.push({
      '@type': 'updateChatReplyMarkup',
      'chat_id': 7,
      'reply_markup_message': _message(
        id: 17,
        chatId: 7,
        text: 'Keyboard',
      ).toJson(),
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.replyMarkupMessageId(7), 17);
    expect(controller.store.message(7, 17)?.text, 'Keyboard');

    json.push({
      '@type': 'updateChatReplyMarkup',
      'chat_id': 7,
      'reply_markup_message': null,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.replyMarkupMessageId(7), 0);

    await controller.callbackQuery(7, 16, Uint8List.fromList([1, 2]));
    final query = json.sent.lastWhere(
      (r) => r['@type'] == 'getCallbackQueryAnswer',
    );
    expect(query['message_id'], 16);
    expect((query['payload']! as Map)['data'], base64.encode([1, 2]));
  });

  test('learns the commands of a bot when its chat opens', () async {
    json.push(
      _chat(
        lastRead: 0,
        unread: 0,
        last: 0,
        type: const {'@type': 'chatTypePrivate', 'user_id': 77},
      ),
    );
    await controller.start();
    await controller.openChat(7);
    expect(controller.store.botUserIdOf(7), 77);
    expect(controller.store.botCommands(7).map((c) => c.command), [
      'start',
      'help',
    ]);
    expect(controller.store.botMenu(7), const BotMenu(text: '', url: ''));

    json.push({
      '@type': 'updateUserFullInfo',
      'user_id': 77,
      'user_full_info': _botFull(['start']),
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.botCommands(7).map((c) => c.command), ['start']);

    // The bot switched its menu button to a Web App.
    json.push({
      '@type': 'updateUserFullInfo',
      'user_id': 77,
      'user_full_info': _botFull(['start'], webApp: 'https://shop.example'),
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(
      controller.store.botMenu(7),
      const BotMenu(text: 'Shop', url: 'https://shop.example'),
    );
    expect(
      await controller.webAppUrl(77, 'https://shop.example'),
      'https://shop.example/app',
    );
    final request = json.sent.lastWhere((r) => r['@type'] == 'getWebAppUrl');
    expect(request['bot_user_id'], 77);

    await controller.sendBotStart(7, 77);
    final start = json.sent.lastWhere(
      (r) => r['@type'] == 'sendBotStartMessage',
    );
    expect(start['bot_user_id'], 77);
  });

  test('opens the comments of a post and follows them', () async {
    await controller.start();
    final thread = await controller.openThread(7, 10);
    expect(thread.chatId, -100);
    expect(thread.threadId, 40);
    expect(thread.replyCount, 2);
    await thread.load();
    expect(thread.messages.map((m) => m.id), [42, 41, 40]);
    // A short page is not the end: TDLib may still have older comments.
    expect(thread.reachedStart, isFalse);
    await thread.loadOlder();
    expect(thread.reachedStart, isTrue);

    json.push({
      '@type': 'updateNewMessage',
      'message': {
        ..._message(id: 43, chatId: -100, text: 'Third').toJson(),
        'topic_id': {'@type': 'messageTopicThread', 'message_thread_id': 40},
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(thread.messages.first.id, 43);
    expect(thread.replyCount, 3);

    await thread.send('Fourth');
    final sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(sent['chat_id'], -100);
    expect((sent['topic_id']! as Map)['message_thread_id'], 40);
    expect((sent['reply_to']! as Map)['message_id'], 40);
    expect(thread.messages.first.id, 44);

    // Answering a comment quotes part of it.
    await thread.send('Fifth', replyTo: 41, quote: 'First', quotePosition: 0);
    final reply = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final replyTo = reply['reply_to']! as Map;
    expect(replyTo['message_id'], 41);
    expect(((replyTo['quote']! as Map)['text']! as Map)['text'], 'First');

    // A file goes into the thread too, under the root.
    await thread.sendFiles(const [
      OutgoingFile(path: '/tmp/a.pdf', kind: OutgoingKind.document),
    ], caption: 'Paper');
    final file = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(file['chat_id'], -100);
    expect((file['topic_id']! as Map)['message_thread_id'], 40);
    expect((file['reply_to']! as Map)['message_id'], 40);
    expect(
      (file['input_message_content']! as Map)['@type'],
      'inputMessageDocument',
    );
    expect(thread.messages.first.id, 44);

    json.push({
      '@type': 'updateDeleteMessages',
      'chat_id': -100,
      'message_ids': [41],
      'is_permanent': true,
      'from_cache': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(thread.messages.map((m) => m.id), [44, 43, 42, 40]);
    expect(thread.replyCount, 2);

    thread.dispose();
    json.push({
      '@type': 'updateNewMessage',
      'message': {
        ..._message(id: 45, chatId: -100, text: 'Late').toJson(),
        'topic_id': {'@type': 'messageTopicThread', 'message_thread_id': 40},
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(thread.messages.first.id, 44);
  });

  test('lists the tags of Saved Messages and opens one', () async {
    await controller.start();
    final tags = controller.openSavedTags();
    await tags.load();
    expect(
      json.sent.lastWhere(
        (r) => r['@type'] == 'getSavedMessagesTags',
      )['saved_messages_topic_id'],
      0,
    );
    expect(tags.tags.map((t) => t.label), ['Work', '']);
    json.push({
      '@type': 'updateSavedMessagesTags',
      'saved_messages_topic_id': 0,
      'tags': {
        '@type': 'savedMessagesTags',
        'tags': [_tag('🔥', 'Ideas', 3)],
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(tags.tags.single.label, 'Ideas');
    await tags.setLabel(const td.ReactionTypeEmoji(emoji: '🔥'), 'Hot');
    final label = json.sent.lastWhere(
      (r) => r['@type'] == 'setSavedMessagesTagLabel',
    );
    expect(label['label'], 'Hot');
    expect((label['tag']! as Map)['emoji'], '🔥');

    final thread = await controller.openSavedTag(
      7,
      const td.ReactionTypeEmoji(emoji: '🔥'),
    );
    expect(thread.isSavedTag, isTrue);
    expect(thread.isStandalone, isTrue);
    await thread.load();
    final search = json.sent.lastWhere(
      (r) => r['@type'] == 'searchSavedMessages',
    );
    expect((search['tag']! as Map)['emoji'], '🔥');
    expect(search['from_message_id'], 0);
    expect(thread.messages.map((m) => m.id), [61, 60]);
    expect(thread.reachedStart, isTrue);

    // A message sent while the tag is open goes to Saved Messages itself.
    await thread.send('Note');
    final sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(sent['chat_id'], 7);
    expect(sent['topic_id'], isNull);
    expect(sent['reply_to'], isNull);

    // Taking the tag off a message drops it from the thread.
    json.push({
      '@type': 'updateMessageInteractionInfo',
      'chat_id': 7,
      'message_id': 61,
      'interaction_info': {
        '@type': 'messageInteractionInfo',
        'view_count': 0,
        'forward_count': 0,
        'reactions': {
          '@type': 'messageReactions',
          'reactions': <Object?>[],
          'are_tags': true,
          'paid_reactors': <Object?>[],
          'can_get_added_reactions': false,
        },
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(thread.messages.map((m) => m.id), isNot(contains(61)));
    thread.dispose();
    tags.dispose();
  });

  test('lists who voted for a poll option', () async {
    await controller.start();
    final voters = await controller.pollVoters(7, 10, 1);
    expect(voters, [MessageSenderId.user(3), MessageSenderId.chat(-5)]);
    final request = json.sent.lastWhere((r) => r['@type'] == 'getPollVoters');
    expect(request['message_id'], 10);
    expect(request['option_id'], 1);
  });

  test('sends a contact', () async {
    await controller.start();
    await controller.sendContact(
      7,
      const td.Contact(
        phoneNumber: '79990001122',
        firstName: 'Vera',
        lastName: '',
        vcard: '',
        userId: 3,
      ),
      replyTo: 10,
    );
    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageContact');
    expect((content['contact']! as Map)['user_id'], 3);
    expect((send['reply_to']! as Map)['message_id'], 10);
  });

  test('follows a poll and votes in it', () async {
    json.history = (_) => [
      td.Message.fromJson({
        ..._message(id: 10, chatId: 7, text: 'Poll').toJson(),
        'content': td.MessagePoll(
          poll: _poll(chosen: null),
          description: const td.FormattedText(text: '', entities: []),
          canAddOption: false,
        ).toJson(),
      }),
    ];
    await controller.start();
    await controller.loadHistory(7);

    await controller.votePoll(7, 10, [1]);
    final vote = json.sent.lastWhere((r) => r['@type'] == 'setPollAnswer');
    expect(vote['message_id'], 10);
    expect(vote['option_ids'], [1]);

    json.push({'@type': 'updatePoll', 'poll': _poll(chosen: 1).toJson()});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final content = controller.store.message(7, 10)!.content as td.MessagePoll;
    expect(content.poll.options[1].isChosen, isTrue);
    expect(content.poll.totalVoterCount, 4);

    await controller.stopPoll(7, 10);
    expect(json.sent.last['@type'], 'stopPoll');
  });

  test('keeps the pinned messages of a chat up to date', () async {
    await controller.start();
    await controller.loadPinned(7);
    expect(controller.store.pinnedIds(7), [50, 20]);
    expect(controller.store.message(7, 20)?.text, 'Pinned');

    json.push({
      '@type': 'updateMessageIsPinned',
      'chat_id': 7,
      'message_id': 20,
      'is_pinned': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.pinnedIds(7), [50]);

    await controller.setPinned(7, 60, pinned: true);
    final pin = json.sent.lastWhere((r) => r['@type'] == 'pinChatMessage');
    expect(pin['message_id'], 60);
    await controller.setPinned(7, 50, pinned: false);
    expect(json.sent.last['@type'], 'unpinChatMessage');
  });

  test('follows membership and mute state of a channel', () async {
    await controller.start();
    json.push(
      _chat(
        lastRead: 0,
        unread: 0,
        last: 8,
        type: {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 99,
          'is_channel': true,
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final store = controller.store;
    expect(store.membership(7), ChatMembership.unknown);

    json.push(_supergroup(99, {'@type': 'chatMemberStatusLeft'}));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(store.membership(7), ChatMembership.left);
    expect(store.canPost(7), isFalse);

    await controller.joinChat(7);
    expect(json.sent.last['@type'], 'joinChat');

    json.push(
      _supergroup(99, {
        '@type': 'chatMemberStatusMember',
        'member_since_date': 0,
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(store.membership(7), ChatMembership.member);
    // A channel's plain member reads, but can't post.
    expect(store.canPost(7), isFalse);
    expect(store.isMuted(7), isFalse);

    await controller.setMuted(7, muted: true);
    final mute = json.sent.last;
    expect(mute['@type'], 'setChatNotificationSettings');
    final settings = mute['notification_settings']! as Map;
    expect(settings['use_default_mute_for'], isFalse);
    expect(settings['mute_for'], greaterThan(0));

    json.push({
      '@type': 'updateChatNotificationSettings',
      'chat_id': 7,
      'notification_settings': {
        '@type': 'chatNotificationSettings',
        'mute_for': 2147483647,
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(store.isMuted(7), isTrue);
  });

  test('finds photos and videos around a message, oldest first', () async {
    await controller.start();

    final found = await controller.mediaAround(7, 20, newer: 5, limit: 11);

    final search = json.sent.lastWhere(
      (r) => r['@type'] == 'searchChatMessages',
    );
    expect(search['chat_id'], 7);
    expect(search['from_message_id'], 20);
    expect(search['offset'], -5);
    expect(search['limit'], 11);
    expect(
      (search['filter']! as Map)['@type'],
      'searchMessagesFilterPhotoAndVideo',
    );
    expect(found.map((m) => m.id), [18, 20, 22]);
  });

  test('sends a caption too long for media as its own message', () async {
    await controller.start();

    await controller.sendFiles(
      7,
      const [OutgoingFile(path: '/a.jpg', kind: OutgoingKind.photo)],
      caption: 'A rather long caption',
      replyTo: 10,
    );

    final sends = [
      for (final r in json.sent)
        if (r['@type'] == 'sendMessage') r,
    ];
    expect(sends, hasLength(2));
    final text = sends.first['input_message_content']! as Map;
    expect(text['@type'], 'inputMessageText');
    expect((text['text']! as Map)['text'], 'A rather long caption');
    expect(sends.first['reply_to'], containsPair('message_id', 10));
    final photo = sends.last['input_message_content']! as Map;
    expect(photo['@type'], 'inputMessagePhoto');
    expect(photo['caption'], isNull);
    expect(sends.last['reply_to'], isNull);
  });

  test('offers free emoji reactions once each, in order', () async {
    await controller.start();

    expect(await controller.quickReactions(7, 1), ['👍', '❤', '😁']);
    expect(await controller.quickReactions(7, 1, limit: 2), ['👍', '❤']);
    // TDLib takes rows of 5 to 25.
    final rows = [
      for (final r in json.sent)
        if (r['@type'] == 'getMessageAvailableReactions') r['row_size'],
    ];
    expect(rows, [8, 5]);

    json.reactionsUnavailable = {'@type': 'reactionUnavailabilityReasonGuest'};
    expect(await controller.quickReactions(7, 1), isEmpty);
  });

  test('offers custom emoji reactions by their ids for the pickers', () async {
    await controller.start();

    final types = await controller.quickReactionTypes(7, 1);
    expect(types, hasLength(4));
    expect(
      types.whereType<td.ReactionTypeCustomEmoji>().map((t) => t.customEmojiId),
      [9],
    );
    // The emoji-only list still fills its limit with emoji.
    expect(await controller.quickReactions(7, 1, limit: 2), ['👍', '❤']);
    final all = await controller.allReactionTypes(7, 1);
    expect(all.whereType<td.ReactionTypeCustomEmoji>(), hasLength(1));
  });

  test('translates a message with Telegram', () async {
    expect(await controller.translate(7, 1, 'en'), 'Hello (en)');
    final request = json.sent.last;
    expect(request['@type'], 'translateMessageText');
    expect(request['chat_id'], 7);
    expect(request['message_id'], 1);
  });

  test('announces a new avatar or colour of a sender', () async {
    await controller.start();
    var changes = 0;
    controller.changes.listen((_) => changes++);

    json.push({
      '@type': 'updateChatAccentColors',
      'chat_id': 7,
      'accent_color_id': 3,
      'background_custom_emoji_id': 0,
      'profile_accent_color_id': -1,
      'profile_background_custom_emoji_id': 0,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(changes, 1);
    expect(controller.store.colorOf(const MessageSenderId.chat(7)), 3);
  });

  test('shows ephemeral content instead of the regular one', () async {
    await controller.start();
    await controller.loadHistory(7);

    json.push({
      '@type': 'updateMessageEphemeralContent',
      'chat_id': 7,
      'message_id': 10,
      'ephemeral_content': {
        '@type': 'ephemeralMessageContent',
        'can_be_saved': true,
        'has_timestamped_media': false,
        'content': {
          '@type': 'messageText',
          'text': {
            '@type': 'formattedText',
            'text': 'Secret',
            'entities': <Object?>[],
          },
        },
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(controller.store.message(7, 10)?.text, 'Secret');
  });

  test('keeps the sender of each message', () async {
    await controller.start();
    await controller.loadHistory(7);
    controller.store.setUserName(1, 'Alina');

    final sender = controller.store.messagesFor(7).single.sender;
    expect(sender, const MessageSenderId.user(1));
    expect(controller.store.nameOf(sender), 'Alina');
    expect(controller.store.nameOf(const MessageSenderId.chat(1)), isNull);
  });

  test('opens, views and closes a chat through TDLib', () async {
    await controller.start();

    await controller.openChat(7);
    await controller.viewMessages(7, [10, 11]);
    await controller.viewMessages(7, []);
    await controller.closeChat(7);

    expect(json.sent.map((request) => request['@type']), [
      'openChat',
      'viewMessages',
      'closeChat',
    ]);
    expect(json.sent[1]['message_ids'], [10, 11]);
    expect(json.sent[1]['force_read'], isFalse);
  });
}

Map<String, Object?> _chat({
  required int lastRead,
  required int unread,
  required int last,
  int mentions = 0,
  int reactions = 0,
  Map<String, Object?> type = const {'@type': 'chatTypePrivate', 'user_id': 2},
  bool canSendText = true,
}) => {
  '@type': 'updateNewChat',
  'chat': {
    '@type': 'chat',
    'id': 7,
    'type': type,
    'title': 'Boris',
    'last_message': _message(id: last, chatId: 7, text: 'Last').toJson(),
    'unread_count': unread,
    'last_read_inbox_message_id': lastRead,
    'last_read_outbox_message_id': 0,
    'unread_mention_count': mentions,
    'unread_reaction_count': reactions,
    'permissions': {
      '@type': 'chatPermissions',
      'can_send_basic_messages': canSendText,
    },
    'positions': <Object?>[],
    'chat_lists': <Object?>[],
    'notification_settings': {'@type': 'chatNotificationSettings'},
    'available_reactions': {
      '@type': 'chatAvailableReactionsAll',
      'max_reaction_count': 11,
    },
    'video_chat': {'@type': 'videoChat'},
  },
};

Map<String, Object?> _tag(String emoji, String label, int count) => {
  '@type': 'savedMessagesTag',
  'tag': {'@type': 'reactionTypeEmoji', 'emoji': emoji},
  'label': label,
  'count': count,
};

Map<String, Object?> _supergroup(int id, Map<String, Object?> status) => {
  '@type': 'updateSupergroup',
  'supergroup': {
    '@type': 'supergroup',
    'id': id,
    'date': 0,
    'status': status,
    'member_count': 10,
    'boost_level': 0,
    'has_automatic_translation': false,
    'has_linked_chat': false,
    'has_location': false,
    'sign_messages': false,
    'show_message_sender': false,
    'join_to_send_messages': false,
    'join_by_request': false,
    'is_slow_mode_enabled': false,
    'is_channel': true,
    'is_broadcast_group': false,
    'is_forum': false,
    'is_direct_messages_group': false,
    'is_administered_direct_messages_group': false,
    'has_direct_messages_group': false,
    'has_forum_tabs': false,
    'paid_message_star_count': 0,
  },
};

/// The full info of bot 77 with [commands], as far as the store reads it.
Map<String, Object?> _botFull(List<String> commands, {String? webApp}) => {
  '@type': 'userFullInfo',
  'gift_settings': {
    '@type': 'giftSettings',
    'accepted_gift_types': {'@type': 'acceptedGiftTypes'},
  },
  'bot_info': {
    '@type': 'botInfo',
    'short_description': '',
    'description': '',
    'manager_bot_user_id': 0,
    if (webApp != null)
      'menu_button': {'@type': 'botMenuButton', 'text': 'Shop', 'url': webApp},
    'commands': [
      for (final command in commands)
        {
          '@type': 'botCommand',
          'command': command,
          'description': 'Does $command',
          'is_ephemeral': false,
        },
    ],
    'privacy_policy_url': '',
    'web_app_background_light_color': 0,
    'web_app_background_dark_color': 0,
    'web_app_header_light_color': 0,
    'web_app_header_dark_color': 0,
    'can_get_revenue_statistics': false,
    'can_manage_emoji_status': false,
    'has_media_previews': false,
  },
};

td.Poll _poll({required int? chosen}) => td.Poll(
  id: 555,
  question: const td.FormattedText(text: 'Tea or coffee?', entities: []),
  options: [
    for (final (i, text) in ['Tea', 'Coffee'].indexed)
      td.PollOption(
        id: '$i',
        text: td.FormattedText(text: text, entities: const []),
        voterCount: i == chosen ? 3 : 1,
        votePercentage: i == chosen ? 75 : 25,
        recentVoterIds: const [],
        isChosen: i == chosen,
        isBeingChosen: false,
        additionDate: 0,
      ),
  ],
  totalVoterCount: chosen == null ? 3 : 4,
  recentVoterIds: const [],
  canGetVoters: false,
  canSeeResults: chosen != null,
  isAnonymous: true,
  allowsMultipleAnswers: false,
  allowsRevoting: true,
  membersOnly: false,
  countryCodes: const [],
  optionOrder: const [0, 1],
  type: const td.PollTypeRegular(),
  openPeriod: 0,
  closeDate: 0,
  isClosed: false,
);

td.Message _message({
  required int id,
  required int chatId,
  required String text,
  td.MessageSendingState? sendingState,
}) => td.Message(
  id: id,
  sendingState: sendingState,
  senderId: const td.MessageSenderUser(userId: 1),
  chatId: chatId,
  isOutgoing: true,
  isPinned: false,
  isFromOffline: false,
  canBeSaved: true,
  hasTimestampedMedia: false,
  isChannelPost: false,
  isPaidStarSuggestedPost: false,
  isPaidGramSuggestedPost: false,
  containsUnreadMention: false,
  containsUnreadPollVotes: false,
  date: id,
  editDate: 0,
  unreadReactions: const [],
  selfDestructIn: 0,
  autoDeleteIn: 0,
  viaBotUserId: 0,
  senderBusinessBotUserId: 0,
  senderBoostCount: 0,
  senderTag: '',
  paidMessageStarCount: 0,
  authorSignature: '',
  mediaAlbumId: 0,
  effectId: 0,
  summaryLanguageCode: '',
  content: td.MessageText(
    text: td.FormattedText(text: text, entities: const []),
  ),
  ephemeralMessageId: 0,
  chatInstance: 0,
);

/// The ids TDLib returns for a history request over [ids], newest first.
List<int> _page(List<int> ids, int from, int offset, int limit) {
  final newestFirst = [...ids]..sort((a, b) => b.compareTo(a));
  var start = from == 0 ? 0 : newestFirst.indexWhere((id) => id <= from);
  if (start < 0) return const [];
  start = (start + offset).clamp(0, newestFirst.length);
  return newestFirst.skip(start).take(limit).toList();
}

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

  /// Delivered as `updateNewMessage` before the history response.
  td.Message? liveDuringHistory;

  /// The history page that starts at a message id (0 is the newest).
  List<td.Message> Function(int fromMessageId)? history;

  /// A whole chat of text messages with these ids, paged as TDLib does
  /// with from_message_id, offset and limit; takes the place of [history].
  List<int>? chat;

  /// When set, getRepliedMessage fails with this TDLib error code.
  int? repliedError;
  int? byDateError;

  /// When set, reactions come back unavailable for this reason.
  Map<String, Object?>? reactionsUnavailable;
  var _nextClientId = 0;

  @override
  int createClientId() => ++_nextClientId;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    sent.add(decoded);
    if (decoded['@type'] == 'getChatHistory' && liveDuringHistory != null) {
      push({
        '@type': 'updateNewMessage',
        'message': liveDuringHistory!.toJson(),
      });
    }
    final response = switch (decoded['@type']) {
      'getChatHistory' when chat != null => {
        '@type': 'messages',
        'total_count': chat!.length,
        'messages': [
          for (final id in _page(
            chat!,
            decoded['from_message_id']! as int,
            decoded['offset']! as int,
            decoded['limit']! as int,
          ))
            _message(id: id, chatId: 7, text: 'm$id').toJson(),
        ],
      },
      'searchChatMessages'
          when (decoded['filter']! as Map)['@type'] ==
              'searchMessagesFilterPinned' =>
        {
          '@type': 'foundChatMessages',
          'total_count': 2,
          'messages': [
            for (final id in [50, 20])
              {
                ..._message(id: id, chatId: 7, text: 'Pinned').toJson(),
                'is_pinned': true,
              },
          ],
          'next_from_message_id': 0,
        },
      'searchChatMessages'
          when (decoded['filter']! as Map)['@type'] ==
              'searchMessagesFilterUnreadMention' =>
        {
          '@type': 'foundChatMessages',
          'total_count': 2,
          'messages': [
            for (final id in [40, 30])
              _message(id: id, chatId: 7, text: '@me').toJson(),
          ],
          'next_from_message_id': 0,
        },
      'getChatHistory' => {
        '@type': 'messages',
        'total_count': 1,
        'messages': [
          for (final message
              in history?.call(decoded['from_message_id']! as int) ??
                  [_message(id: 10, chatId: 7, text: 'From history')])
            message.toJson(),
        ],
      },
      'editMessageText' || 'editMessageCaption' => _message(
        id: decoded['message_id']! as int,
        chatId: 7,
        text: 'Edited',
      ).toJson(),
      'sendMessageAlbum' => {
        '@type': 'messages',
        'total_count': 2,
        'messages': [
          _message(id: 30, chatId: 7, text: '').toJson(),
          _message(id: 31, chatId: 7, text: '').toJson(),
        ],
      },
      'searchChatMessages' => {
        '@type': 'foundChatMessages',
        'total_count': 3,
        'messages': [
          for (final id in [22, 20, 18])
            _message(id: id, chatId: 7, text: '').toJson(),
        ],
        'next_from_message_id': 18,
      },
      'joinChat' => {'@type': 'chatJoinResultSuccess'},
      'translateMessageText' => {
        '@type': 'formattedText',
        'text': 'Hello (${decoded['to_language_code']})',
        'entities': <Object?>[],
      },
      'forwardMessages' => {
        '@type': 'messages',
        'total_count': 0,
        'messages': <Object?>[],
      },
      'getMessageAvailableReactions' => {
        '@type': 'availableReactions',
        'top_reactions': [
          _reaction({'@type': 'reactionTypeEmoji', 'emoji': '👍'}),
          _reaction({
            '@type': 'reactionTypeEmoji',
            'emoji': '🔥',
          }, premium: true),
          _reaction({'@type': 'reactionTypeCustomEmoji', 'custom_emoji_id': 9}),
        ],
        'recent_reactions': [
          _reaction({'@type': 'reactionTypeEmoji', 'emoji': '👍'}),
        ],
        'popular_reactions': [
          _reaction({'@type': 'reactionTypeEmoji', 'emoji': '❤'}),
          _reaction({'@type': 'reactionTypeEmoji', 'emoji': '😁'}),
        ],
        'allow_custom_emoji': true,
        'are_tags': false,
        'unavailability_reason': reactionsUnavailable,
      },
      'getMessageViewers' => {
        '@type': 'messageViewers',
        'viewers': [
          {'@type': 'messageViewer', 'user_id': 3, 'view_date': 1700000000},
        ],
      },
      'getMessageAddedReactions' => {
        '@type': 'addedReactions',
        'total_count': 1,
        'reactions': [
          {
            '@type': 'addedReaction',
            'type': {'@type': 'reactionTypeEmoji', 'emoji': '👍'},
            'sender_id': {'@type': 'messageSenderUser', 'user_id': 2},
            'is_outgoing': false,
            'date': 1700000000,
          },
        ],
        'next_offset': '',
      },
      'getMessageReadDate' => {
        '@type': 'messageReadDateRead',
        'read_date': 1700000000,
      },
      'reportChat' when decoded['option_id'] == '' => {
        '@type': 'reportChatResultOptionRequired',
        'title': 'Report for',
        'options': [
          {'@type': 'reportOption', 'id': 'AQ==', 'text': 'Spam'},
          {'@type': 'reportOption', 'id': 'Ag==', 'text': 'Violence'},
        ],
      },
      'reportChat' when decoded['text'] == '' => {
        '@type': 'reportChatResultTextRequired',
        'option_id': decoded['option_id'],
        'is_optional': true,
      },
      'reportChat' => {'@type': 'reportChatResultOk'},
      'getChatMessageByDate' when byDateError != null => {
        '@type': 'error',
        'code': byDateError,
        'message': 'Failed',
      },
      'getChatMessageByDate' => _message(
        id: 10,
        chatId: 7,
        text: 'That day',
      ).toJson(),
      'getRepliedMessage' when repliedError != null => {
        '@type': 'error',
        'code': repliedError,
        'message': 'Failed',
      },
      'getRepliedMessage' => _message(
        id: 3,
        chatId: 7,
        text: 'Quoted',
      ).toJson(),
      'sendMessage' when decoded['chat_id'] == -100 => _message(
        id: 44,
        chatId: -100,
        text: 'Fourth',
        sendingState: const td.MessageSendingStatePending(sendingId: 1),
      ).toJson(),
      'getMessageThread' => {
        '@type': 'messageThreadInfo',
        'chat_id': -100,
        'message_thread_id': 40,
        'reply_info': {
          '@type': 'messageReplyInfo',
          'reply_count': 2,
          'recent_replier_ids': <Object?>[],
          'last_read_inbox_message_id': 0,
          'last_read_outbox_message_id': 0,
          'last_message_id': 42,
        },
        'unread_message_count': 0,
        'messages': [_message(id: 40, chatId: -100, text: 'Post').toJson()],
      },
      'getMessageThreadHistory' => {
        '@type': 'messages',
        'total_count': 2,
        // Only the newest page has comments; an older one is empty.
        'messages': decoded['from_message_id'] == 0
            ? [
                _message(id: 42, chatId: -100, text: 'Second').toJson(),
                _message(id: 41, chatId: -100, text: 'First').toJson(),
              ]
            : <Object?>[],
      },
      'sendMessage' => {
        ..._message(
          id: 12,
          chatId: 7,
          text: 'Sent text',
          sendingState: const td.MessageSendingStatePending(sendingId: 1),
        ).toJson(),
        // A scheduled message comes back marked so.
        'scheduling_state': ?(decoded['options'] as Map?)?['scheduling_state'],
      },
      'getSavedMessagesTags' => {
        '@type': 'savedMessagesTags',
        'tags': [_tag('🔥', 'Work', 2), _tag('👍', '', 1)],
      },
      'searchSavedMessages' => {
        '@type': 'foundChatMessages',
        'total_count': 2,
        'messages': [
          _message(id: 61, chatId: 7, text: 'Tagged two').toJson(),
          _message(id: 60, chatId: 7, text: 'Tagged one').toJson(),
        ],
        'next_from_message_id': 0,
      },
      'getPollVoters' => {
        '@type': 'pollVoters',
        'total_count': 2,
        'voters': [
          {
            '@type': 'pollVoter',
            'voter_id': {'@type': 'messageSenderUser', 'user_id': 3},
            'date': 0,
          },
          {
            '@type': 'pollVoter',
            'voter_id': {'@type': 'messageSenderChat', 'chat_id': -5},
            'date': 0,
          },
        ],
      },
      'sendBotStartMessage' => _message(
        id: 13,
        chatId: 7,
        text: '/start',
        sendingState: const td.MessageSendingStatePending(sendingId: 1),
      ).toJson(),
      'getOption' when decoded['name'] == 'message_caption_length_max' => {
        '@type': 'optionValueInteger',
        'value': '10',
      },
      'getLinkPreview'
          when ((decoded['text']! as Map)['text']! as String).contains(
            'example.com',
          ) =>
        {
          '@type': 'linkPreview',
          'url': 'https://example.com/a',
          'display_url': 'example.com/a',
          'site_name': 'Example',
          'title': 'An example page',
          'description': {
            '@type': 'formattedText',
            'text': 'Nothing to see',
            'entities': <Object?>[],
          },
          'author': '',
          'type': {'@type': 'linkPreviewTypeArticle'},
          'has_large_media': false,
          'show_large_media': false,
          'show_media_above_description': false,
          'skip_confirmation': false,
          'show_above_text': false,
          'instant_view_version': 0,
        },
      'getLinkPreview' => {
        '@type': 'error',
        'code': 404,
        'message': 'Not Found',
      },
      'getChatScheduledMessages' => {
        '@type': 'messages',
        'total_count': 2,
        'messages': [
          {
            ..._message(id: 31, chatId: 7, text: 'Second').toJson(),
            'date': 1900000600,
          },
          {
            ..._message(id: 30, chatId: 7, text: 'First').toJson(),
            'date': 1900000000,
          },
        ],
      },
      'getUser' when decoded['user_id'] == 77 => {
        '@type': 'user',
        'id': 77,
        'first_name': 'Helper',
        'last_name': '',
        'usernames': null,
        'phone_number': '',
        'status': {'@type': 'userStatusEmpty'},
        'profile_photo': null,
        'accent_color_id': 0,
        'background_custom_emoji_id': 0,
        'profile_accent_color_id': -1,
        'profile_background_custom_emoji_id': 0,
        'emoji_status': null,
        'is_contact': false,
        'is_mutual_contact': false,
        'is_close_friend': false,
        'verification_status': null,
        'is_premium': false,
        'is_support': false,
        'restriction_reason': '',
        'restriction_info': null,
        'has_active_stories': false,
        'has_unread_active_stories': false,
        'restricts_new_chats': false,
        'paid_message_star_count': 0,
        'paid_message_gram_count': 0,
        'have_access': true,
        'type': {
          '@type': 'userTypeBot',
          'can_be_edited': false,
          'can_join_groups': true,
          'can_read_all_group_messages': false,
          'has_main_web_app': false,
          'is_inline': false,
          'inline_query_placeholder': '',
          'need_location': false,
          'can_connect_to_business': false,
          'can_be_added_to_attachment_menu': false,
          'active_user_count': 0,
        },
        'language_code': '',
        'added_to_attachment_menu': false,
      },
      'getUserFullInfo' when decoded['user_id'] == 77 => _botFull([
        'start',
        'help',
      ]),
      'getWebAppUrl' => {
        '@type': 'webAppUrl',
        'url': 'https://shop.example/app',
      },
      'getCallbackQueryAnswer' => {
        '@type': 'callbackQueryAnswer',
        'text': '',
        'show_alert': false,
        'url': '',
      },
      _ => {'@type': 'ok'},
    };
    _queue.add(
      jsonEncode({
        ...response,
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (decoded['@type'] == 'close') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
    }
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}

Map<String, Object?> _reaction(
  Map<String, Object?> type, {
  bool premium = false,
}) => {'@type': 'availableReaction', 'type': type, 'needs_premium': premium};

const _italic = td.TextEntity(
  offset: 0,
  length: 4,
  type: td.TextEntityTypeItalic(),
);
