import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_media_editor/mollygram_media_editor.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../session/providers.dart';
import 'emoji_sticker_panel.dart';

/// The media editor's sticker picker: the emoji and sticker panel in a
/// floating card. A still sticker goes in as its file; an animated one as
/// its still thumbnail, since the picture cannot move. Completes with
/// null when closed without a choice.
Future<StickerPick?> showStickerPicker(BuildContext context) =>
    showGeneralDialog<StickerPick>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, _, _) => const _StickerPickerDialog(),
      transitionBuilder: (context, animation, _, child) {
        final t = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: t,
          child: ScaleTransition(
            scale: Tween(begin: 0.97, end: 1.0).animate(t),
            child: child,
          ),
        );
      },
    );

class _StickerPickerDialog extends ConsumerWidget {
  const _StickerPickerDialog();

  Future<void> _pickSticker(
    BuildContext context,
    WidgetRef ref,
    td.Sticker sticker,
  ) async {
    final files = ref.read(telegramSessionProvider).requireValue.files;
    final thumbnail = sticker.thumbnail;
    // The file to place: the sticker itself when it is a still picture,
    // its thumbnail when it is animated and the thumbnail is still.
    final td.File? source = switch (sticker.format) {
      td.StickerFormatWebp() => sticker.sticker,
      _ =>
        thumbnail != null && _isStill(thumbnail.format) ? thumbnail.file : null,
    };
    if (source == null) return;
    String? path = downloadedPath(files.latest(source));
    if (path == null) {
      try {
        path = downloadedPath(
          await files.downloadNow(source.id, priority: DownloadPriority.media),
        );
      } on Object {
        return;
      }
    }
    if (path == null || !context.mounted) return;
    Navigator.of(context).pop(StickerFilePick(path));
  }

  static bool _isStill(td.ThumbnailFormat format) =>
      format is td.ThumbnailFormatWebp ||
      format is td.ThumbnailFormatPng ||
      format is td.ThumbnailFormatJpeg;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    type: MaterialType.transparency,
    child: Center(
      child: SizedBox(
        width: 380,
        child: Glass(
          radius: 14,
          padding: EdgeInsets.zero,
          child: EmojiStickerPanel(
            height: (MediaQuery.sizeOf(context).height - 200).clamp(260, 440),
            onEmoji: (emoji) => Navigator.of(context).pop(EmojiPick(emoji)),
            onSticker: (sticker) => _pickSticker(context, ref, sticker),
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    ),
  );
}
