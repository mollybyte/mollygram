import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_media/mollygram_media.dart';

import 'fake_circle_player.dart';

void main() {
  const placeholder = ColoredBox(
    key: ValueKey('placeholder'),
    color: Color(0xFF8E9A93),
  );
  final texture = find.byKey(const ValueKey('texture'));
  final cover = find.byKey(const ValueKey('placeholder'));

  Widget wrap(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );

  testWidgets('without a player only the placeholder is shown', (t) async {
    await t.pumpWidget(
      wrap(
        const CircleVideo(player: null, size: 240, placeholder: placeholder),
      ),
    );

    expect(cover, findsOneWidget);
    expect(texture, findsNothing);
    expect(t.getSize(find.byType(CircleVideo)), const Size(240, 240));
  });

  testWidgets('the placeholder covers the texture until frames arrive', (
    t,
  ) async {
    final player = FakeCirclePlayer(640);
    await t.pumpWidget(
      wrap(CircleVideo(player: player, size: 240, placeholder: placeholder)),
    );
    await player.open(const CircleSource.asset('a.mp4'));
    await t.pump();

    // The texture is mounted from the start so it can draw the first frame.
    expect(texture, findsOneWidget);
    expect(cover, findsOneWidget);

    player.showFrames();
    await t.pump();
    expect(cover, findsNothing);

    // A reused player must not flash the previous circle's last frame.
    await player.stop();
    await player.open(const CircleSource.asset('b.mp4'));
    await t.pump();
    expect(cover, findsOneWidget);
  });

  test('sources compare by uri', () {
    expect(
      const CircleSource.asset('a.mp4'),
      const CircleSource.uri('asset:///a.mp4'),
    );
    expect(CircleSource.file('/tmp/c.mp4').uri, 'file:///tmp/c.mp4');
  });

  test('qualities stay within the Telegram limit', () {
    expect(CircleQuality.values.map((q) => q.side), [384, 512, 640]);
    expect(CircleQuality.standard.side, 640);
    expect(CircleQuality.maxDuration, const Duration(seconds: 60));
  });
}
