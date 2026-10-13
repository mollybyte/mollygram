import 'package:flutter/widgets.dart';

import 'circle_player.dart';

/// A round video message.
///
/// Shows [placeholder] (usually the thumbnail TDLib sends with the message)
/// until the [player] has frames of its current source on screen. The
/// texture stays mounted underneath the whole time, so it starts drawing as
/// soon as frames arrive and a reused player never flashes the previous
/// circle's last frame.
class CircleVideo extends StatelessWidget {
  const CircleVideo({
    super.key,
    required this.player,
    required this.size,
    this.placeholder,
  });

  /// Null while no player is attached, for example for a circle that is
  /// not playing.
  final CirclePlayer? player;

  /// Diameter in logical pixels.
  final double size;

  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    final cover = placeholder ?? const ColoredBox(color: Color(0xFF8E9A93));
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: player == null
            ? cover
            : Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(child: player.buildTexture()),
                  ValueListenableBuilder(
                    valueListenable: player.status,
                    builder: (context, status, child) =>
                        status == CircleStatus.showing
                        ? const SizedBox()
                        : child!,
                    child: cover,
                  ),
                ],
              ),
      ),
    );
  }
}
