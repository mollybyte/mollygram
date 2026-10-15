import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/chat/media_gallery.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

void main() {
  test('pages through the media around the opened message', () async {
    // The chat holds photos 1 to 100; the user opens 50.
    final calls = <(int, int, int)>[];
    Future<List<ConversationMessage>> load(
      int from, {
      int newer = 0,
      int limit = 30,
    }) async {
      calls.add((from, newer, limit));
      final first = (from - (limit - newer) + 1).clamp(1, 100);
      final last = (from + newer).clamp(1, 100);
      return [for (var id = first; id <= last; id++) _photo(id)];
    }

    final gallery = MediaGallery.chat(_photo(50), load: load);
    expect(gallery.entries, hasLength(1));
    expect(gallery.hasPrevious, isFalse);

    await gallery.start();
    expect(calls.single, (50, 15, 31));
    expect(gallery.current.message!.id, 50);
    expect(gallery.entries.first.message!.id, 35);
    expect(gallery.entries.last.message!.id, 65);
    expect(gallery.hasPrevious && gallery.hasNext, isTrue);

    // Near the older end, the next page loads and the page stays put.
    gallery.go(-12);
    expect(gallery.current.message!.id, 38);
    await pumpEventQueue();
    expect(calls.last, (35, 0, 31));
    expect(gallery.entries.first.message!.id, 5);
    expect(gallery.current.message!.id, 38);

    gallery.dispose();
  });

  test('stops at the ends of the chat', () async {
    Future<List<ConversationMessage>> load(
      int from, {
      int newer = 0,
      int limit = 30,
    }) async => [_photo(2), _photo(3), _photo(4)];

    final gallery = MediaGallery.chat(_photo(3), load: load);
    await gallery.start();
    expect(gallery.entries.map((e) => e.message!.id), [2, 3, 4]);

    gallery
      ..go(1)
      ..go(1);
    expect(gallery.current.message!.id, 4);
    expect(gallery.hasNext, isFalse);
    gallery.dispose();
  });

  test('shows a GIF on its own', () async {
    var loaded = false;
    final gallery = MediaGallery.chat(
      _message(9, {
        '@type': 'messageAnimation',
        'animation': {
          '@type': 'animation',
          'animation': _file(9),
          'duration': 2,
          'width': 100,
          'height': 100,
        },
        'caption': _text,
      }),
      load: (from, {newer = 0, limit = 30}) async {
        loaded = true;
        return const [];
      },
    );
    await gallery.start();
    expect(loaded, isFalse);
    expect(gallery.current.item, isA<AnimationItem>());
    gallery.dispose();
  });
}

const _text = {'@type': 'formattedText', 'text': '', 'entities': <Object?>[]};

Map<String, Object?> _file(int id) => {
  '@type': 'file',
  'id': id,
  'size': 10,
  'expected_size': 10,
  'local': {'@type': 'localFile', 'path': ''},
  'remote': {'@type': 'remoteFile', 'id': 'r$id', 'unique_id': 'u$id'},
};

ConversationMessage _photo(int id) => _message(id, {
  '@type': 'messagePhoto',
  'photo': {'@type': 'photo', 'sizes': <Object?>[]},
  'caption': _text,
});

ConversationMessage _message(int id, Map<String, Object?> content) =>
    ConversationMessage(
      td.Message.fromJson({
        '@type': 'message',
        'id': id,
        'sender_id': {'@type': 'messageSenderUser', 'user_id': 1},
        'chat_id': 7,
        'date': 1700000000 + id,
        'content': content,
      }),
    );
