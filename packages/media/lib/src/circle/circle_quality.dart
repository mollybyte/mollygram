/// The side of a video message (a "circle") in pixels.
///
/// Telegram accepts video messages up to 640x640 and 60 seconds. Mollygram
/// offers three sizes; H.264 is the default codec for all of them.
enum CircleQuality {
  p384(384),
  p512(512),
  p640(640);

  const CircleQuality(this.side);

  /// Width and height of the square video, in pixels.
  final int side;

  /// The largest size Telegram accepts, so recorded circles keep the most
  /// detail.
  static const standard = p640;

  /// The longest video message Telegram accepts.
  static const maxDuration = Duration(seconds: 60);

  String get label => '${side}x$side';
}
