import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'media_content.dart';

/// The strip of stickers that stand for the emoji in the draft, floating
/// over the composer like the mention popup; a click sends one.
class StickerSuggestionStrip extends StatelessWidget {
  const StickerSuggestionStrip({
    super.key,
    required this.stickers,
    required this.onPick,
  });

  final List<td.Sticker> stickers;
  final void Function(td.Sticker sticker) onPick;

  static const double side = 64;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Glass(
        radius: 14,
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: side,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: stickers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final sticker = stickers[index];
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(sticker),
                  child: StickerContent(sticker: sticker, side: side),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
