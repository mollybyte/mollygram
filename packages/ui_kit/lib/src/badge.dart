import 'package:flutter/widgets.dart';

import 'theme/colors.dart';

/// The unread counter of a chat row.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    super.key,
    required this.count,
    this.muted = false,
    this.onAccent = false,
  });

  final int count;

  /// A muted chat uses a gray badge.
  final bool muted;

  /// Inverted colors for a selected (accent-filled) row.
  final bool onAccent;

  /// Telegram-style compact label: 999 and below as is, then 1K, 1.2K, 15K.
  static String label(int count) {
    if (count < 1000) return '$count';
    if (count < 10000) {
      final tenths = (count / 100).floor();
      return tenths % 10 == 0 ? '${tenths ~/ 10}K' : '${tenths / 10}K';
    }
    return '${count ~/ 1000}K';
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onAccent ? c.onAccent : (muted ? c.muted : c.accent),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label(count),
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w600,
          color: onAccent ? c.accent : c.onAccent,
        ),
      ),
    );
  }
}
