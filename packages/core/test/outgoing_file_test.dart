import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

OutgoingFile _file(String path) =>
    OutgoingFile(path: path, kind: outgoingKindOf(path));

void main() {
  test('picks the kind from the extension', () {
    expect(outgoingKindOf('/a/Sea.JPG'), OutgoingKind.photo);
    expect(outgoingKindOf('/a/clip.mov'), OutgoingKind.video);
    expect(outgoingKindOf('/a/cat.gif'), OutgoingKind.animation);
    expect(outgoingKindOf('/a/song.mp3'), OutgoingKind.audio);
    expect(outgoingKindOf('/a/report.pdf'), OutgoingKind.document);
    expect(outgoingKindOf('/a.b/README'), OutgoingKind.document);
    expect(outgoingKindOf(r'C:\a.b\README'), OutgoingKind.document);
  });

  test('groups photos and videos, documents and music apart', () {
    final groups = groupForSending([
      _file('1.jpg'),
      _file('2.mp4'),
      _file('3.pdf'),
      _file('4.zip'),
      _file('5.gif'),
      _file('6.png'),
    ]);
    expect([for (final group in groups) group.length], [2, 2, 1, 1]);
  });

  test('keeps photos apart when they are marked alone', () {
    final groups = groupForSending([
      _file('1.jpg').copyWith(alone: true),
      _file('2.jpg').copyWith(alone: true),
      _file('3.jpg').copyWith(alone: true),
    ]);
    expect([for (final group in groups) group.length], [1, 1, 1]);
  });

  test('splits albums at ten', () {
    final groups = groupForSending([
      for (var i = 0; i < 12; i++) _file('$i.jpg'),
    ]);
    expect([for (final group in groups) group.length], [10, 2]);
  });

  test('sends a photo compressed and a document untouched', () {
    final photo = inputContentOf(
      const OutgoingFile(
        path: '/a.jpg',
        kind: OutgoingKind.photo,
        width: 800,
        height: 600,
      ),
      caption: const td.FormattedText(text: 'Sea', entities: []),
    );
    expect(photo, isA<td.InputMessagePhoto>());
    expect((photo as td.InputMessagePhoto).photo.width, 800);
    expect(photo.caption?.text, 'Sea');

    final document = inputContentOf(_file('/a.jpg').asDocument());
    expect(document, isA<td.InputMessageDocument>());
  });

  test('hides a photo behind a spoiler, never a document', () {
    final photo = inputContentOf(_file('/a.jpg').copyWith(spoiler: true));
    expect((photo as td.InputMessagePhoto).hasSpoiler, isTrue);
    final document = inputContentOf(
      _file('/a.jpg').copyWith(spoiler: true).asDocument(),
    );
    expect(document, isA<td.InputMessageDocument>());
  });

  test('sets a self-destruct timer and sends such media alone', () {
    final timed = inputContentOf(_file('/a.jpg').copyWith(selfDestruct: 10));
    expect(
      (timed as td.InputMessagePhoto).selfDestructType?.toJson(),
      const td.MessageSelfDestructTypeTimer(selfDestructTime: 10).toJson(),
    );
    final once = inputContentOf(
      _file('/a.jpg').copyWith(selfDestruct: OutgoingFile.viewOnce),
    );
    expect(
      (once as td.InputMessagePhoto).selfDestructType,
      isA<td.MessageSelfDestructTypeImmediately>(),
    );
    final groups = groupForSending([
      _file('/a.jpg').copyWith(selfDestruct: 10),
      _file('/b.jpg'),
      _file('/c.jpg'),
    ]);
    expect([for (final g in groups) g.length], [1, 2]);
  });

  test('sends an edited video with its thumbnail and cover', () {
    final video = inputContentOf(
      const OutgoingFile(
        path: '/clip.mp4',
        kind: OutgoingKind.video,
        duration: 7,
        thumbnail: '/thumb.jpg',
        cover: '/cover.jpg',
      ),
    );
    expect(video, isA<td.InputMessageVideo>());
    final input = (video as td.InputMessageVideo).video;
    expect(input.duration, 7);
    expect(
      (input.thumbnail!.thumbnail as td.InputFileLocal).path,
      '/thumb.jpg',
    );
    expect((input.cover! as td.InputFileLocal).path, '/cover.jpg');

    final plain = inputContentOf(_file('/clip.mp4').copyWith(duration: 3));
    expect((plain as td.InputMessageVideo).video.thumbnail, isNull);
    expect(plain.video.cover, isNull);
  });
}
