import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_media/mollygram_media.dart';

/// Video message players, reused between circles so scrolling never pays
/// for creating a decoder twice.
final circlePlayerPoolProvider = Provider<CirclePlayerPool>((ref) {
  final pool = CirclePlayerPool(
    create: (side) => MediaKitCirclePlayer(outputSide: side),
  );
  ref.onDispose(() => unawaited(pool.dispose()));
  return pool;
});

/// The one player for voice messages and music: starting a track stops
/// the previous one, as in Telegram.
final audioPlayerProvider = Provider<AudioTrackPlayer>((ref) {
  final player = AudioTrackPlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});

/// What [audioPlayerProvider] is playing: a message of a chat.
typedef AudioTrackKey = ({int chatId, int messageId});
