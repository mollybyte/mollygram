import 'package:flutter/widgets.dart';

import 'theme/colors.dart';

/// The unread counter of a chat row.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    super.key,
    required this.count,
    this.muted = false,
    this.onAccent = false,
    this.label,
  });

  final int count;

  /// The text to show instead of [count], such as a compact, localized
  /// "1.2K". The app formats it; the kit has no locale rules of its own.
  final String? label;

  /// A muted chat uses a gray badge.
  final bool muted;

  /// Inverted colors for a selected (accent-filled) row.
  final bool onAccent;

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
        label ?? '$count',
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
