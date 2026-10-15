import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'media_content.dart';
import 'td_file.dart';

/// The preview of the link in the draft, above the composer's field: the
/// site's picture, name and title, a button that moves the preview above
/// or below the text, and one that drops it from the message.
class ComposerLinkPreview extends StatelessWidget {
  const ComposerLinkPreview({
    super.key,
    required this.preview,
    required this.aboveText,
    required this.onToggleAbove,
    required this.onRemove,
  });

  final td.LinkPreview preview;

  /// Whether the sent message shows the preview above its text.
  final bool aboveText;
  final VoidCallback onToggleAbove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final photo = switch (preview.type) {
      td.LinkPreviewTypePhoto(:final photo) => photo,
      td.LinkPreviewTypeArticle(:final photo) => photo,
      td.LinkPreviewTypeVideo(:final cover) => cover,
      _ => null,
    };
    final title = preview.title.isNotEmpty
        ? preview.title
        : preview.siteName.isNotEmpty
        ? preview.siteName
        : preview.displayUrl;
    final text = preview.description.text.isNotEmpty
        ? preview.description.text
        : preview.displayUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 0, 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: c.accent, width: 2)),
              ),
              child: Row(
                children: [
                  if (photo != null && photo.sizes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: TdImage(
                            file: photoSizeFor(photo, 64)?.photo,
                            minithumbnail: photo.minithumbnail,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(
                            c,
                            weight: FontWeight.w600,
                            color: c.accent,
                            height: 1.3,
                          ),
                        ),
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(c, color: c.fg2, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          MgIconButton(
            icon: MgIcons.chevronUp,
            tooltip: aboveText
                ? l10n.linkPreviewBelowText
                : l10n.linkPreviewAboveText,
            selected: aboveText,
            iconSize: 14,
            onPressed: onToggleAbove,
          ),
          MgIconButton(
            icon: MgIcons.close,
            tooltip: l10n.removeLinkPreview,
            iconSize: 14,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
