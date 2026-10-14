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
}
