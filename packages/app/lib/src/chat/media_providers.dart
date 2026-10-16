import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_media/mollygram_media.dart';

import 'voice_autoplay.dart';

/// Video message players, reused between circles so scrolling never pays
/// for creating a decoder twice.
final circlePlayerPoolProvider = Provider<CirclePlayerPool>((ref) {
  final pool = CirclePlayerPool(
    create: (side) => MediaKitCirclePlayer(outputSide: side),
  );
  ref.onDispose(() => unawaited(pool.dispose()));
  return pool;
});

/// The video message that is playing with sound, which the player capsule
/// in the chat header shows. Null when no circle is playing aloud.
typedef ActiveCircle = ({int chatId, int messageId, CirclePlayer player});

final activeCircleProvider = Provider<ValueNotifier<ActiveCircle?>>((ref) {
  final active = ValueNotifier<ActiveCircle?>(null);
  // A voice message or music starting takes the sound from the circle.
  final audio = ref.read(audioPlayerProvider);
  void onTrack() {
    if (audio.track.value != null) active.value = null;
  }

  audio.track.addListener(onTrack);
  ref.onDispose(() {
    audio.track.removeListener(onTrack);
    active.dispose();
  });
  return active;
});

/// The one player for voice messages and music: starting a track stops
/// the previous one, and a finished one goes on to the next, as in
/// Telegram.
final audioPlayerProvider = Provider<AudioTrackPlayer>((ref) {
  final player = AudioTrackPlayer();
  continueAudioPlayback(ref, player);
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});

/// What [audioPlayerProvider] is playing: a message of a chat.
typedef AudioTrackKey = ({int chatId, int messageId});
