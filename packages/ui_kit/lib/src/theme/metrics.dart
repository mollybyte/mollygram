import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Layout choices from Appearance that the design leaves open: how round
/// media corners are and how tight the lists sit. Read them with
/// `MgMetrics.of(context)`; `buildMgTheme` installs the defaults.
@immutable
class MgMetrics extends ThemeExtension<MgMetrics> {
  const MgMetrics({this.mediaRadius = 8, this.compact = false});

  /// Corner radius of photos, videos and cards in messages, in points.
  final double mediaRadius;

  /// Tighter rows in the chat list and less air between messages.
  final bool compact;

  static const defaults = MgMetrics();

  /// Vertical padding of a chat list row.
  double get rowPadding => compact ? 4 : 8;

  /// Air between two messages of the same sender.
  double get messageGap => compact ? 2 : 6;

  static MgMetrics of(BuildContext context) =>
      Theme.of(context).extension<MgMetrics>() ?? defaults;

  @override
  MgMetrics copyWith({double? mediaRadius, bool? compact}) => MgMetrics(
    mediaRadius: mediaRadius ?? this.mediaRadius,
    compact: compact ?? this.compact,
  );

  @override
  MgMetrics lerp(MgMetrics? other, double t) {
    if (other == null) return this;
    return MgMetrics(
      mediaRadius: lerpDouble(mediaRadius, other.mediaRadius, t)!,
      compact: t < 0.5 ? compact : other.compact,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MgMetrics &&
      other.mediaRadius == mediaRadius &&
      other.compact == compact;

  @override
  int get hashCode => Object.hash(mediaRadius, compact);
}
