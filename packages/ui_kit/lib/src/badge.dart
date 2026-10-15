import 'package:flutter/widgets.dart';

import 'icons.dart';
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
  /// A chat marked as unread with nothing new shows an empty badge.
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
        label ?? (count > 0 ? '$count' : ''),
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

/// A round badge with a glyph: "@" for unread mentions, a heart for unread
/// reactions. Mentions keep the accent even in a muted chat, as in the
/// official client; reactions are red.
class GlyphBadge extends StatelessWidget {
  const GlyphBadge.mention({super.key, this.onAccent = false})
    : _reaction = false;

  const GlyphBadge.reaction({super.key, this.onAccent = false})
    : _reaction = true;

  final bool _reaction;

  /// Inverted colors for a selected (accent-filled) row.
  final bool onAccent;

  static const Color reactionColor = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final fill = _reaction ? reactionColor : c.accent;
    final fg = onAccent ? fill : c.onAccent;
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onAccent ? c.onAccent : fill,
        shape: BoxShape.circle,
      ),
      child: _reaction
          ? MgIcon(MgIcons.heart, size: 11, stroke: 2.8, color: fg)
          : Text(
              '@',
              style: TextStyle(
                fontSize: 11.5,
                height: 1,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
    );
  }
}
