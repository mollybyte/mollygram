import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'td_file.dart';

/// Why a message's media stays hidden until the user taps it: a spoiler,
/// self-destructing media, or content the chat marked 18+.
enum Concealment { spoiler, secret, sensitive }

/// The reason [message]'s media must be hidden, or null to show it.
Concealment? concealmentOf(ConversationMessage message) {
  if (message.message.restrictionInfo?.hasSensitiveContent ?? false) {
    return Concealment.sensitive;
  }
  return switch (message.content) {
    td.MessagePhoto(:final isSecret) ||
    td.MessageVideo(:final isSecret) ||
    td.MessageVideoNote(:final isSecret) when isSecret => Concealment.secret,
    td.MessagePhoto(:final hasSpoiler) ||
    td.MessageVideo(:final hasSpoiler) ||
    td.MessageAnimation(
      :final hasSpoiler,
    ) when hasSpoiler => Concealment.spoiler,
    _ => null,
  };
}

/// The tiny blurred preview TDLib sends with media, the only thing shown
/// of concealed media.
td.Minithumbnail? minithumbnailOf(td.MessageContent content) =>
    switch (content) {
      td.MessagePhoto(:final photo) => photo.minithumbnail,
      td.MessageVideo(:final video) => video.minithumbnail,
      td.MessageAnimation(:final animation) => animation.minithumbnail,
      td.MessageVideoNote(:final videoNote) => videoNote.minithumbnail,
      _ => null,
    };

/// Hides [child] behind a heavy blur of [minithumbnail] until it is
/// tapped. Nothing of [child] is built, and so nothing downloaded, before
/// that. [onReveal] runs on the tap, for example to start a
/// self-destruct timer.
class Concealed extends StatefulWidget {
  const Concealed({
    super.key,
    required this.reason,
    required this.minithumbnail,
    required this.size,
    required this.child,
    this.onReveal,
  });

  final Concealment reason;
  final td.Minithumbnail? minithumbnail;
  final Size size;
  final Widget child;
  final VoidCallback? onReveal;

  @override
  State<Concealed> createState() => _ConcealedState();
}

class _ConcealedState extends State<Concealed> {
  var _revealed = false;

  void _reveal() {
    setState(() => _revealed = true);
    widget.onReveal?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_revealed) return widget.child;
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.hiddenMedia,
      onTap: _reveal,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _reveal,
          child: SizedBox.fromSize(
            size: widget.size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: 14,
                      sigmaY: 14,
                      tileMode: TileMode.clamp,
                    ),
                    child: TdImage(
                      minithumbnail: widget.minithumbnail,
                      download: false,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.mediaPill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      switch (widget.reason) {
                        Concealment.sensitive => l10n.sensitiveMedia,
                        Concealment.secret => l10n.secretMedia,
                        Concealment.spoiler => l10n.spoilerMedia,
                      },
                      style: mgTextStyle(
                        c,
                        size: MgType.small,
                        weight: FontWeight.w500,
                        color: const Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
