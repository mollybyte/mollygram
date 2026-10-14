import 'package:mollygram_core/src/text_edit.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

td.TextEntity _bold(int offset, int length) => td.TextEntity(
  offset: offset,
  length: length,
  type: const td.TextEntityTypeBold(),
);

List<(int, int)> _spans(List<td.TextEntity> entities) => [
  for (final e in entities) (e.offset, e.length),
];

void main() {
  test('keeps formatting before the change and shifts what follows', () {
    // "Hello world, bye": "Hello" and "bye" are bold; "world" becomes
    // "there".
    final carried = carryEntities('Hello world, bye', 'Hello there, bye', [
      _bold(0, 5),
      _bold(13, 3),
    ]);
    expect(_spans(carried), [(0, 5), (13, 3)]);

    final longer = carryEntities('Hi Bob, ok', 'Hi Roberta, ok', [_bold(8, 2)]);
    expect(_spans(longer), [(12, 2)]);
  });

  test('stretches an entity around the change and cuts overlaps', () {
    // Typo fixed inside a bold word.
    expect(_spans(carryEntities('teh word', 'the word', [_bold(0, 3)])), [
      (0, 3),
    ]);
    // Bold "abc|def" where "cd" is replaced by "XY": the text typed
    // after "ab" joins the left part, the right part starts at "e".
    expect(
      _spans(carryEntities('abcdef', 'abXYef', [_bold(0, 3), _bold(3, 3)])),
      [(0, 4), (4, 2)],
    );
    // A bold word deleted entirely disappears.
    expect(
      _spans(carryEntities('a big cat', 'a cat', [_bold(2, 3)])),
      <(int, int)>[],
    );
  });

  test('keeps formatting between two separate fixes', () {
    // "Teh *bold* wrod": both typos fixed, the bold word untouched.
    expect(
      _spans(carryEntities('Teh bold wrod', 'The bold word', [_bold(4, 4)])),
      [(4, 4)],
    );
  });

  test('leaves out entities TDLib detects by itself', () {
    final url = td.TextEntity(
      offset: 0,
      length: 13,
      type: const td.TextEntityTypeUrl(),
    );
    expect(carryEntities('https://a.org', 'https://a.org!', [url]), isEmpty);
  });

  test('changes nothing when the text is the same', () {
    expect(_spans(carryEntities('ok', 'ok', [_bold(0, 2)])), [(0, 2)]);
  });
}
