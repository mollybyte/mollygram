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
import 'td_file.dart';

/// The emoji and sticker panel over the composer. An emoji goes into the
/// text with [onEmoji] and the panel stays; a sticker is sent at once
/// with [onSticker].
class EmojiStickerPanel extends ConsumerWidget {
  const EmojiStickerPanel({
    super.key,
    required this.onEmoji,
    required this.onSticker,
    this.onGif,
    this.onCustomEmoji,
    required this.onClose,
    this.height = 400,
  });

  final ValueChanged<String> onEmoji;
  final ValueChanged<td.Sticker> onSticker;

  /// A saved GIF picked in the GIF tab; sent at once, like a sticker. Without
  /// it the panel has no GIF tab, as when it picks a sticker for the editor.
  final ValueChanged<td.Animation>? onGif;

  /// A custom emoji picked in the Custom tab, which goes into the text.
  /// Without it the panel has no such tab.
  final ValueChanged<td.Sticker>? onCustomEmoji;
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
      tabs: [
        l10n.emojiTab,
        l10n.stickersTab,
        if (onCustomEmoji != null) l10n.customEmojiTab,
        if (onGif != null) l10n.gifsTab,
      ],
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
        _StickerTab(
          library: session.stickers,
          languages: {language, 'en'}.toList(),
          onPick: onSticker,
        ),
        if (onCustomEmoji case final onCustomEmoji?)
          _StickerTab(
            library: session.stickers,
            languages: const [],
            onPick: onCustomEmoji,
            emojiSets: true,
          ),
        if (onGif case final onGif?)
          _GifTab(library: session.stickers, onPick: onGif),
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
  const _StickerTab({
    required this.library,
    required this.languages,
    required this.onPick,
    this.emojiSets = false,
  });

  /// Shows the custom emoji sets, with no recent or favorite rows and no
  /// search, instead of the sticker sets.
  final bool emojiSets;

  final StickerLibrary library;

  /// The languages a search understands, such as `ru` and `en`.
  final List<String> languages;
  final ValueChanged<td.Sticker> onPick;

  @override
  State<_StickerTab> createState() => _StickerTabState();
}

class _StickerTabState extends State<_StickerTab> {
  final _grid = SectionedGridController();
  List<_StickerSection>? _sections;
  var _section = 0;
  var _failed = false;

  /// The search: its text, the stickers found for it (null while they
  /// load) and a counter that drops stale answers.
  var _query = '';
  List<td.Sticker>? _found;
  var _searchId = 0;
  Timer? _debounce;

  static const double _cell = 66;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String value) {
    final text = value.trim();
    _debounce?.cancel();
    final id = ++_searchId;
    if (text.isEmpty) {
      setState(() {
        _query = '';
        _found = null;
      });
      return;
    }
    setState(() {
      _query = text;
      _found = null;
    });
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      List<td.Sticker> found;
      try {
        found = await widget.library.searchStickers(
          text,
          languages: widget.languages,
        );
      } on Object {
        found = const [];
      }
      if (!mounted || id != _searchId) return;
      setState(() => _found = found);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sections == null && !_failed) unawaited(_load());
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    final library = widget.library;
    try {
      final (recent, favorites, sets) = widget.emojiSets
          ? (
              const <td.Sticker>[],
              const <td.Sticker>[],
              await library.installedEmojiSets(),
            )
          : await (
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
    final searching = _query.isNotEmpty;
    final found = _found;
    final Widget body;
    if (searching) {
      body = found == null
          ? const SizedBox.shrink()
          : found.isEmpty
          ? Center(
              child: Text(
                l10n.noStickersFound,
                style: mgTextStyle(c, color: c.fg2),
              ),
            )
          : SectionedGrid(
              key: ValueKey(_query),
              cellExtent: _cell,
              sections: [
                GridSection(
                  title: l10n.stickerSearchResults,
                  count: found.length,
                  builder: (context, i) => _StickerCell(
                    sticker: found[i],
                    onTap: () => widget.onPick(found[i]),
                  ),
                ),
              ],
            );
    } else if (sections.isEmpty) {
      body = Center(
        child: Text(l10n.noStickerSets, style: mgTextStyle(c, color: c.fg2)),
      );
    } else {
      body = SectionedGrid(
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
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.emojiSets)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: MgSearchField(
              hintText: l10n.stickerSearch,
              onChanged: _onQuery,
            ),
          ),
        Expanded(child: body),
        if (!searching && sections.isNotEmpty)
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

/// The user's saved GIFs in a grid; each plays while the pointer is over
/// it and goes out with a click.
class _GifTab extends StatefulWidget {
  const _GifTab({required this.library, required this.onPick});

  final StickerLibrary library;
  final ValueChanged<td.Animation> onPick;

  @override
  State<_GifTab> createState() => _GifTabState();
}

class _GifTabState extends State<_GifTab> {
  List<td.Animation>? _gifs;
  var _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_gifs == null && !_failed) unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final gifs = await widget.library.savedAnimations();
      if (mounted) setState(() => _gifs = gifs);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final gifs = _gifs;
    if (gifs == null) {
      return _failed
          ? Center(
              child: Text(l10n.gifsFailed, style: mgTextStyle(c, color: c.fg2)),
            )
          : const SizedBox.shrink();
    }
    if (gifs.isEmpty) {
      return Center(
        child: Text(l10n.noGifs, style: mgTextStyle(c, color: c.fg2)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 124,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: gifs.length,
      itemBuilder: (context, i) => _GifCell(
        key: ValueKey(gifs[i].animation.id),
        animation: gifs[i],
        onTap: () => widget.onPick(gifs[i]),
      ),
    );
  }
}

/// A saved GIF in the panel: its cover at rest, playing under the pointer.
class _GifCell extends StatefulWidget {
  const _GifCell({super.key, required this.animation, required this.onTap});

  final td.Animation animation;
  final VoidCallback onTap;

  @override
  State<_GifCell> createState() => _GifCellState();
}

class _GifCellState extends State<_GifCell> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final animation = widget.animation;
    return PanelCell(
      label: animation.fileName,
      onTap: widget.onTap,
      onHover: (hover) => setState(() => _hover = hover),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
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
