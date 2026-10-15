import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_media_editor/mollygram_media_editor.dart';

void main() {
  const length = Duration(seconds: 10);

  test('identity keeps everything', () {
    const edit = VideoEdit();
    expect(edit.isIdentity, isTrue);
    expect(edit.isTrimmed, isFalse);
    expect(edit.endIn(length), length);
    expect(edit.lengthIn(length), length);
    expect(edit.coverIn(length), Duration.zero);
  });

  test('trim, mute and cover', () {
    const edit = VideoEdit(
      start: Duration(seconds: 2),
      end: Duration(seconds: 7),
      muted: true,
      cover: Duration(seconds: 4),
    );
    expect(edit.isIdentity, isFalse);
    expect(edit.isTrimmed, isTrue);
    expect(edit.lengthIn(length), const Duration(seconds: 5));
    expect(edit.coverIn(length), const Duration(seconds: 4));
    // An end past the video is cut to the video.
    expect(
      edit.copyWith(end: const Duration(seconds: 30)).endIn(length),
      length,
    );
  });

  test('a cover outside the kept part falls back to the start', () {
    const edit = VideoEdit(
      start: Duration(seconds: 2),
      end: Duration(seconds: 7),
      cover: Duration(seconds: 9),
    );
    expect(edit.coverIn(length), const Duration(seconds: 2));
  });

  test('copyWith clears nullable fields on purpose', () {
    const edit = VideoEdit(
      end: Duration(seconds: 7),
      cover: Duration(seconds: 4),
    );
    expect(edit.copyWith(muted: true).end, const Duration(seconds: 7));
    expect(edit.copyWith(end: null).end, isNull);
    expect(edit.copyWith(cover: null).cover, isNull);
    expect(edit.copyWith(), edit);
  });

  test('formatTime', () {
    expect(formatTime(Duration.zero), '0:00.0');
    expect(formatTime(const Duration(milliseconds: 8450)), '0:08.5');
    expect(formatTime(const Duration(seconds: 125)), '2:05.0');
  });
}
