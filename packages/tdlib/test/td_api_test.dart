import 'dart:convert';
import 'dart:typed_data';

import 'package:mollygram_tdlib/mollygram_tdlib.dart';
import 'package:test/test.dart';

void main() {
  test('int64 comes in and goes out as a string, int53 as a number', () {
    final update = tdFromJson(
      jsonDecode('''
        {"@type": "updateChatReadInbox", "chat_id": -1001234567890,
         "last_read_inbox_message_id": 1048576, "unread_count": 3}
      ''') as Map<String, Object?>,
    );
    expect((update as UpdateChatReadInbox).chatId, -1001234567890);
    expect(update.toJson()['chat_id'], -1001234567890);

    final photo = InputChatPhotoPrevious.fromJson({
      '@type': 'inputChatPhotoPrevious',
      'chat_photo_id': '9223372036854775807',
    });
    expect(photo.chatPhotoId, 9223372036854775807);
    expect(photo.toJson()['chat_photo_id'], '9223372036854775807');
  });

  test('nested objects and lists are decoded by @type', () {
    final text = tdFromJson({
      '@type': 'formattedText',
      'text': 'hello',
      'entities': [
        {
          '@type': 'textEntity',
          'offset': 0,
          'length': 5,
          'type': {'@type': 'textEntityTypeBold'},
        },
      ],
    }) as FormattedText;
    expect(text.text, 'hello');
    expect(text.entities.single.type, isA<TextEntityTypeBold>());
    expect(
      jsonDecode(jsonEncode(text.toJson())),
      jsonDecode(jsonEncode(FormattedText.fromJson(text.toJson()).toJson())),
    );
  });

  test('sealed hierarchy allows an exhaustive switch', () {
    String describe(AuthorizationState state) => switch (state) {
      AuthorizationStateReady() => 'ready',
      AuthorizationStateWaitPhoneNumber() => 'phone',
      _ => 'other',
    };
    expect(
      describe(
        AuthorizationState.fromJson({'@type': 'authorizationStateReady'}),
      ),
      'ready',
    );
  });

  test('bytes are sent as base64', () {
    final credentials = EncryptedCredentials(
      data: Uint8List.fromList([1, 2, 3, 250]),
      hash: Uint8List(0),
      secret: Uint8List.fromList([0]),
    );
    final json = credentials.toJson();
    expect(json['data'], 'AQID+g==');
    final back = EncryptedCredentials.fromJson(json);
    expect(back.data, [1, 2, 3, 250]);
    expect(back.secret, [0]);
  });

  test('null fields are omitted, missing primitives default to zero', () {
    final send = SendMessage(
      chatId: 1,
      inputMessageContent: InputMessageText(
        text: FormattedText(text: 'hi', entities: []),
        clearDraft: true,
      ),
    );
    final json = send.toJson();
    expect(json.containsKey('reply_to'), isFalse);
    expect(json.containsKey('options'), isFalse);
    expect(
      (json['input_message_content']! as Map<String, Object?>)['@type'],
      'inputMessageText',
    );

    final user = tdFromJson({'@type': 'userTypeRegular'});
    expect(user, isA<UserTypeRegular>());
    final option = OptionValueInteger.fromJson({'@type': 'optionValueInteger'});
    expect(option.value, 0);
  });

  test('unknown @type and wrong type throw TdDecodeException', () {
    expect(
      () => tdFromJson({'@type': 'definitelyNotATdType'}),
      throwsA(isA<TdDecodeException>()),
    );
    expect(
      () => AuthorizationState.fromJson({'@type': 'ok'}),
      throwsA(isA<TdDecodeException>()),
    );
  });

  test('names clashing with dart:core get the Td prefix', () {
    expect(
      tdFromJson({'@type': 'error', 'code': 400, 'message': 'BAD'}),
      isA<TdError>(),
    );
  });

  test('schema version is pinned', () {
    expect(tdlibVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    expect(tdlibCommit, hasLength(40));
  });
}
