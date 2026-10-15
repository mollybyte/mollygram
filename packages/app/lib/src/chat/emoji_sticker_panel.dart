import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import 'media_content.dart';
import 'recent_emoji.dart';

/// The emoji and sticker panel over the composer. An emoji goes into the
/// text with [onEmoji] and the panel stays; a sticker is sent at once
/// with [onSticker].
class EmojiStickerPanel extends ConsumerWidget {
  const EmojiStickerPanel({
    super.key,
    required this.onEmoji,
    required this.onSticker,
    required this.onClose,
    this.height = 400,
  });

  final ValueChanged<String> onEmoji;
  final ValueChanged<td.Sticker> onSticker;
  final VoidCallback onClose;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(telegramSessionProvider).requireValue;
    final language = Localizations.localeOf(context).languageCode;
    return EmojiPanel(
      height: height,
      onClose: onClose,
      tabs: [l10n.emojiTab, l10n.stickersTab],
      children: [
        EmojiTab(
          labels: EmojiTabLabels(
            search: l10n.emojiSearch,
            recent: l10n.recentlyUsed,
            noResults: l10n.noEmojiFound,
            groups: {
              EmojiGroup.smileys: l10n.emojiSmileys,
              EmojiGroup.people: l10n.emojiPeople,
              EmojiGroup.animals: l10n.emojiAnimals,
              EmojiGroup.food: l10n.emojiFood,
              EmojiGroup.travel: l10n.emojiTravel,
              EmojiGroup.activities: l10n.emojiActivities,
              EmojiGroup.objects: l10n.emojiObjects,
              EmojiGroup.symbols: l10n.emojiSymbols,
              EmojiGroup.flags: l10n.emojiFlags,
            },
          ),
          recent: ref.watch(recentEmojiProvider),
          search: (query) => session.stickers.searchEmoji(
            query,
            languages: {language, 'en'}.toList(),
          ),
          onPick: (emoji) {
            ref.read(recentEmojiProvider.notifier).use(emoji);
            onEmoji(emoji);
          },
        ),
        _StickerTab(library: session.stickers, onPick: onSticker),
      ],
    );
  }
}

/// A run of stickers in the sticker tab: recent, favorite or one set.
final class _StickerSection {
  _StickerSection({
    required this.title,
    required this.icon,
    required this.size,
    this.stickers,
    this.setId,
  });

  final String title;
  final Widget icon;

  /// How many stickers the set holds, known before they load.
  final int size;
  List<td.Sticker>? stickers;

  int get count => stickers?.length ?? size;
  final int? setId;
}

class _StickerTab extends StatefulWidget {
  const _StickerTab({required this.library, required this.onPick});

  final StickerLibrary library;
  final ValueChanged<td.Sticker> onPick;

  @override
  State<_StickerTab> createState() => _StickerTabState();
}

class _StickerTabState extends State<_StickerTab> {
  final _grid = SectionedGridController();
  List<_StickerSection>? _sections;
  var _section = 0;
  var _failed = false;

  static const double _cell = 66;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sections == null && !_failed) unawaited(_load());
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    final library = widget.library;
    try {
      final (recent, favorites, sets) = await (
        library.recent(),
        library.favorites(),
        library.installedSets(),
      ).wait;
      if (!mounted) return;
      final sections = [
        if (recent.isNotEmpty)
          _StickerSection(
            title: l10n.recentlyUsed,
            icon: const MgIcon(MgIcons.recent, size: 17),
            size: recent.length,
            stickers: recent,
          ),
        if (favorites.isNotEmpty)
          _StickerSection(
            title: l10n.favoriteStickers,
            icon: const MgIcon(MgIcons.favorite, size: 17),
            size: favorites.length,
            stickers: favorites,
          ),
        for (final set in sets)
          _StickerSection(
            title: set.title,
            icon: set.covers.isEmpty
                ? Text(
                    set.title.characters.firstOrNull ?? '',
                    style: const TextStyle(fontSize: 13),
                  )
                : StickerContent(
                    sticker: set.covers.first,
                    side: 22,
                    animate: false,
                  ),
            size: set.size,
            setId: set.id,
          ),
      ];
      setState(() => _sections = sections);
      // The sets themselves load one by one, in order, so the first ones
      // fill in first.
      for (final section in sections) {
        final id = section.setId;
        if (id == null) continue;
        List<td.Sticker> stickers;
        try {
          stickers = await library.setStickers(id);
        } on Object {
          continue;
        }
        if (!mounted) return;
        setState(() => section.stickers = stickers);
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final sections = _sections;
    if (sections == null) {
      return _failed
          ? Center(
              child: Text(
                l10n.stickersFailed,
                style: mgTextStyle(c, color: c.fg2),
              ),
            )
          : const SizedBox.shrink();
    }
    if (sections.isEmpty) {
      return Center(
        child: Text(l10n.noStickerSets, style: mgTextStyle(c, color: c.fg2)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SectionedGrid(
            cellExtent: _cell,
            controller: _grid,
            onSection: (section) => setState(() => _section = section),
            sections: [
              for (final section in sections)
                GridSection(
                  title: section.title,
                  count: section.count,
                  builder: (context, i) {
                    final stickers = section.stickers;
                    if (stickers == null || i >= stickers.length) {
                      return const SizedBox.shrink();
                    }
                    return _StickerCell(
                      sticker: stickers[i],
                      onTap: () => widget.onPick(stickers[i]),
                    );
                  },
                ),
            ],
          ),
        ),
        PanelSectionBar(
          selected: _section,
          labels: [for (final section in sections) section.title],
          items: [for (final section in sections) section.icon],
          onSelect: _grid.jumpTo,
        ),
      ],
    );
  }
}

/// A sticker in the panel. Animated ones play while the pointer is over
/// them, so a page of them stays calm and cheap.
class _StickerCell extends StatefulWidget {
  const _StickerCell({required this.sticker, required this.onTap});

  final td.Sticker sticker;
  final VoidCallback onTap;

  @override
  State<_StickerCell> createState() => _StickerCellState();
}

class _StickerCellState extends State<_StickerCell> {
  var _hover = false;

  @override
  Widget build(BuildContext context) => PanelCell(
    label: widget.sticker.emoji,
    onTap: widget.onTap,
    onHover: (hover) => setState(() => _hover = hover),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: StickerContent(sticker: widget.sticker, side: 56, animate: _hover),
    ),
  );
}
