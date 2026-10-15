import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_media/mollygram_media.dart';

void main() {
  test('the speed is kept without loading the player', () async {
    final player = AudioTrackPlayer();
    addTearDown(player.dispose);
    expect(player.rate.value, 1);
    await player.setRate(1.5);
    expect(player.rate.value, 1.5);
    expect(AudioTrackPlayer.rates, [1.0, 1.5, 2.0]);
  });

  test('a completion with nothing loaded reports no track', () async {
    final player = AudioTrackPlayer();
    addTearDown(player.dispose);
    Object? completed;
    player.onCompleted = (key) => completed = key;
    player.debugComplete();
    expect(completed, isNull);
    expect(player.track.value, isNull);
    expect(player.playing.value, isFalse);
  });
}
