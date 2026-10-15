import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'formatted_text.dart';
import 'message_tile.dart' show SenderAvatar;

/// A channel's sponsored message under its timeline, flat like the rest:
/// the sponsor's photo and title with a "Sponsored" tag, the text, and the
/// sponsor's button. Telegram's terms ask every client to show it.
class SponsoredMessageCard extends StatefulWidget {
  const SponsoredMessageCard({
    super.key,
    required this.message,
    required this.onViewed,
    required this.onOpen,
  });

  final td.SponsoredMessage message;

  /// Called once the message is on screen, so TDLib counts the view.
  final VoidCallback onViewed;

  /// Called when the button or the text is clicked, before the sponsor's
  /// link opens.
  final VoidCallback onOpen;

  @override
  State<SponsoredMessageCard> createState() => _SponsoredMessageCardState();
}

class _SponsoredMessageCardState extends State<SponsoredMessageCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onViewed();
    });
  }

  Future<void> _open() async {
    widget.onOpen();
    try {
      await openLink(widget.message.sponsor.url);
    } on Object {
      // No browser to hand the link to; the click still counted.
    }
  }

  void _about(BuildContext context, Offset position) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final message = widget.message;
    final lines = [
      l10n.sponsoredAbout,
      if (message.sponsor.info.isNotEmpty) message.sponsor.info,
      if (message.additionalInfo.isNotEmpty) message.additionalInfo,
    ];
    unawaited(
      showMgPopover(
        context,
        position: position,
        child: Glass(
          radius: 12,
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, line) in lines.indexed) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Text(
                    line,
                    style: mgTextStyle(
                      c,
                      size: MgType.caption,
                      color: i == 0 ? c.fg : c.fg2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final message = widget.message;
    final photo = message.sponsor.photo;
    final text = switch (message.content) {
      td.MessageText(:final text) => text,
      _ => const td.FormattedText(text: '', entities: []),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.bubbleIn,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.fg.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SenderAvatar(
            name: message.title,
            size: 36,
            photo: photo == null || photo.sizes.isEmpty
                ? null
                : photo.sizes.first.photo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(c, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Tag(
                      label: message.isRecommended
                          ? l10n.recommended
                          : l10n.sponsored,
                      onTap: (position) => _about(context, position),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => unawaited(_open()),
                    child: FormattedTextView(text: text),
                  ),
                ),
                const SizedBox(height: 8),
                _Button(
                  label: message.buttonText.isEmpty
                      ? l10n.sponsoredOpen
                      : message.buttonText,
                  onTap: () => unawaited(_open()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The small "Sponsored" tag; a click explains it.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.onTap});

  final String label;
  final void Function(Offset position) onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapUp: (details) => onTap(details.globalPosition),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: c.fg2.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: mgTextStyle(c, size: MgType.small, color: c.fg2),
          ),
        ),
      ),
    );
  }
}

/// The sponsor's full-width button, tinted with the accent.
class _Button extends StatefulWidget {
  const _Button({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_Button> createState() => _ButtonState();
}

class _ButtonState extends State<_Button> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: _hover ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: mgTextStyle(c, weight: FontWeight.w600, color: c.accent),
          ),
        ),
      ),
    );
  }
}
