import 'package:flutter/widgets.dart';

import 'icons.dart';
import 'theme/colors.dart';
import 'theme/theme.dart';

/// The height of the chat row's badges: TelegramSwift's 11 pt count with
/// its padding.
const double _badgeSize = 20;

/// Centres the count on the badge's middle rather than on the line box.
const _tightText = TextHeightBehavior(
  applyHeightToFirstAscent: false,
  applyHeightToLastDescent: false,
);

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
    // The muted text grey is too light under a white count in dark themes.
    final mutedFill = c.isDark
        ? Color.lerp(c.muted, const Color(0xFF000000), 0.35)!
        : c.muted;
    return Container(
      constraints: const BoxConstraints(minWidth: _badgeSize),
      height: _badgeSize,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onAccent ? c.onAccent : (muted ? mutedFill : c.accent),
        borderRadius: BorderRadius.circular(_badgeSize / 2),
      ),
      child: Text(
        label ?? (count > 0 ? '$count' : ''),
        textHeightBehavior: _tightText,
        style: mgTextStyle(
          c,
          size: MgType.tiny,
          weight: MgWeight.medium,
          height: 1,
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
      width: _badgeSize,
      height: _badgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onAccent ? c.onAccent : fill,
        shape: BoxShape.circle,
      ),
      child: _reaction
          ? MgIcon(MgIcons.heart, size: 12, stroke: 2.6, color: fg)
          : Text(
              '@',
              textHeightBehavior: _tightText,
              style: mgTextStyle(
                c,
                size: MgType.caption,
                weight: MgWeight.semibold,
                height: 1,
                color: fg,
              ),
            ),
    );
  }
}
