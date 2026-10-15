import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'media_content.dart';
import 'td_file.dart';

/// The id a bot gave an inline result, whatever its kind.
String inlineResultId(td.InlineQueryResult result) => switch (result) {
  td.InlineQueryResultArticle(:final id) => id,
  td.InlineQueryResultContact(:final id) => id,
  td.InlineQueryResultLocation(:final id) => id,
  td.InlineQueryResultVenue(:final id) => id,
  td.InlineQueryResultGame(:final id) => id,
  td.InlineQueryResultAnimation(:final id) => id,
  td.InlineQueryResultAudio(:final id) => id,
  td.InlineQueryResultDocument(:final id) => id,
  td.InlineQueryResultPhoto(:final id) => id,
  td.InlineQueryResultSticker(:final id) => id,
  td.InlineQueryResultVideo(:final id) => id,
  td.InlineQueryResultVoiceNote(:final id) => id,
};

bool _isMedia(td.InlineQueryResult result) => switch (result) {
  td.InlineQueryResultAnimation() ||
  td.InlineQueryResultPhoto() ||
  td.InlineQueryResultVideo() ||
  td.InlineQueryResultSticker() => true,
  _ => false,
};

/// An inline bot's answers, floating over the composer like the sticker
/// strip: a grid when they are all pictures (GIFs, photos, videos,
/// stickers), rows otherwise; a click sends one via the bot.
class InlineResultsPanel extends StatelessWidget {
  const InlineResultsPanel({
    super.key,
    required this.results,
    required this.loading,
    required this.onPick,
    this.onMore,
  });

  final List<td.InlineQueryResult> results;
  final bool loading;
  final void Function(td.InlineQueryResult result) onPick;

  /// Called when the list nears its end and the bot may have more.
  final VoidCallback? onMore;

  static const double _width = 420;
  static const double _height = 250;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final Widget body;
    if (results.isEmpty) {
      body = SizedBox(
        height: 36,
        width: 220,
        child: Center(
          child: Text(
            loading ? l10n.inlineSearching : l10n.inlineNoResults,
            style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
          ),
        ),
      );
    } else {
      final grid = results.every(_isMedia);
      body = SizedBox(
        width: _width,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _height),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (onMore != null &&
                  notification.metrics.extentAfter < 120 &&
                  notification is ScrollUpdateNotification) {
                onMore!();
              }
              return false;
            },
            child: grid
                ? GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 104,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemCount: results.length,
                    itemBuilder: (context, index) => _MediaCell(
                      result: results[index],
                      onTap: () => onPick(results[index]),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: results.length,
                    itemBuilder: (context, index) => _ResultRow(
                      result: results[index],
                      onTap: () => onPick(results[index]),
                    ),
                  ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Glass(radius: 14, padding: const EdgeInsets.all(6), child: body),
      ),
    );
  }
}

/// A picture result: a GIF plays while the pointer is over it.
class _MediaCell extends StatefulWidget {
  const _MediaCell({required this.result, required this.onTap});

  final td.InlineQueryResult result;
  final VoidCallback onTap;

  @override
  State<_MediaCell> createState() => _MediaCellState();
}

class _MediaCellState extends State<_MediaCell> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final (label, child) = switch (widget.result) {
      td.InlineQueryResultAnimation(:final animation, :final title) => (
        title.isEmpty ? animation.fileName : title,
        LayoutBuilder(
          builder: (context, constraints) => _hover
              ? AnimationContent(
                  animation: animation,
                  size: constraints.biggest,
                )
              : TdImage(
                  thumbnail: animation.thumbnail?.file,
                  minithumbnail: animation.minithumbnail,
                ),
        ),
      ),
      td.InlineQueryResultPhoto(:final photo, :final title) => (
        title,
        TdImage(
          file: photo.sizes.isEmpty ? null : photo.sizes.first.photo,
          minithumbnail: photo.minithumbnail,
        ),
      ),
      td.InlineQueryResultVideo(:final video, :final title) => (
        title,
        TdImage(
          thumbnail: video.thumbnail?.file,
          minithumbnail: video.minithumbnail,
        ),
      ),
      td.InlineQueryResultSticker(:final sticker) => (
        sticker.emoji,
        Center(
          child: StickerContent(sticker: sticker, side: 88, animate: _hover),
        ),
      ),
      _ => ('', const SizedBox.shrink()),
    };
    return PanelCell(
      label: label,
      onTap: widget.onTap,
      onHover: (hover) => setState(() => _hover = hover),
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
    );
  }
}

/// Any other result as a row: a thumbnail or the title's first letter,
/// the title and a line of description.
class _ResultRow extends StatefulWidget {
  const _ResultRow({required this.result, required this.onTap});

  final td.InlineQueryResult result;
  final VoidCallback onTap;

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final (title, subtitle, thumbnail) = switch (widget.result) {
      td.InlineQueryResultArticle(
        :final title,
        :final description,
        :final url,
        :final thumbnail,
      ) =>
        (title, description.isEmpty ? url : description, thumbnail?.file),
      td.InlineQueryResultAudio(:final audio) => (
        audio.title.isEmpty ? audio.fileName : audio.title,
        audio.performer,
        audio.albumCoverThumbnail?.file,
      ),
      td.InlineQueryResultDocument(
        :final document,
        :final title,
        :final description,
      ) =>
        (
          title.isEmpty ? document.fileName : title,
          description,
          document.thumbnail?.file,
        ),
      td.InlineQueryResultVoiceNote(:final title) => (title, '', null),
      td.InlineQueryResultLocation(:final title, :final thumbnail) => (
        title,
        '',
        thumbnail?.file,
      ),
      td.InlineQueryResultVenue(:final venue, :final thumbnail) => (
        venue.title,
        venue.address,
        thumbnail?.file,
      ),
      td.InlineQueryResultContact(:final contact, :final thumbnail) => (
        '${contact.firstName} ${contact.lastName}'.trim(),
        contact.phoneNumber,
        thumbnail?.file,
      ),
      td.InlineQueryResultGame(:final game) => (
        game.title,
        game.description,
        game.photo.sizes.isEmpty ? null : game.photo.sizes.first.photo,
      ),
      td.InlineQueryResultAnimation(:final animation, :final title) => (
        title.isEmpty ? animation.fileName : title,
        '',
        animation.thumbnail?.file,
      ),
      td.InlineQueryResultPhoto(
        :final photo,
        :final title,
        :final description,
      ) =>
        (
          title,
          description,
          photo.sizes.isEmpty ? null : photo.sizes.first.photo,
        ),
      td.InlineQueryResultVideo(
        :final video,
        :final title,
        :final description,
      ) =>
        (title, description, video.thumbnail?.file),
      td.InlineQueryResultSticker(:final sticker) => (sticker.emoji, '', null),
    };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          label: title,
          button: true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hover ? c.fg.withValues(alpha: 0.06) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                    dimension: 40,
                    child: thumbnail != null
                        ? TdImage(file: thumbnail)
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.14),
                            ),
                            child: Center(
                              child: Text(
                                title.isEmpty ? '' : title[0].toUpperCase(),
                                style: mgTextStyle(
                                  c,
                                  color: c.accent,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(c, weight: FontWeight.w500),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(
                            c,
                            size: MgType.caption,
                            color: c.fg2,
                          ),
                        ),
                    ],
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
