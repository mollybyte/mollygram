import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../glass/glass.dart';
import '../icons.dart';
import '../sidebar/folder_tabs.dart';
import '../sidebar/search_field.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'emoji_data.dart';

export 'emoji_data.dart' show EmojiGroup;

/// The floating glass panel above the composer with a tab for emoji and
/// one for stickers. [tabs] names each of [children]; a tab keeps its
/// scroll position while another one is shown.
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({
    super.key,
    required this.tabs,
    required this.children,
    this.height = 400,
    this.onClose,
  }) : assert(tabs.length == children.length);

  final List<String> tabs;
  final List<Widget> children;
  final double height;

  /// Esc inside the panel.
  final VoidCallback? onClose;

  static const double width = 352;

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): ?widget.onClose,
      },
      // Grows out of the emoji button's corner as it fades in.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : MgMotion.standard,
        curve: MgMotion.enter,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.97 + 0.03 * t,
            alignment: Alignment.bottomRight,
            child: child,
          ),
        ),
        child: SizedBox(
          width: EmojiPanel.width,
          height: widget.height,
          child: Glass(
            radius: MgRadius.popover,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: MgSpace.m,
                    bottom: MgSpace.xs,
                  ),
                  child: Center(
                    child: FolderSegments(
                      selected: _tab,
                      segments: [
                        for (final (i, label) in widget.tabs.indexed)
                          FolderSegment(
                            label: label,
                            onTap: () => setState(() => _tab = i),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: IndexedStack(index: _tab, children: widget.children),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One titled run of cells in a [SectionedGrid].
final class GridSection {
  const GridSection({
    required this.title,
    required this.count,
    required this.builder,
  });

  final String title;
  final int count;
  final IndexedWidgetBuilder builder;
}

/// Jumps a [SectionedGrid] to one of its sections.
final class SectionedGridController {
  _SectionedGridState? _state;

  void jumpTo(int section) => _state?._jumpTo(section);
}

/// Sections of square cells under small titles, scrolling as one list.
/// Cells are [cellExtent] tall and as wide as fits, so the offset of each
/// section is known without laying it out; [onSection] reports the
/// section at the top as the list scrolls.
class SectionedGrid extends StatefulWidget {
  const SectionedGrid({
    super.key,
    required this.sections,
    required this.cellExtent,
    this.controller,
    this.onSection,
  });

  final List<GridSection> sections;
  final double cellExtent;
  final SectionedGridController? controller;
  final ValueChanged<int>? onSection;

  static const double titleHeight = 26;
  static const double padding = MgSpace.m;

  @override
  State<SectionedGrid> createState() => _SectionedGridState();
}

class _SectionedGridState extends State<SectionedGrid> {
  final _scroll = ScrollController();
  var _columns = 1;
  var _current = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _scroll.addListener(_report);
  }

  @override
  void didUpdateWidget(SectionedGrid old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _scroll.dispose();
    super.dispose();
  }

  /// Where each section's title starts.
  List<double> _offsets() {
    final offsets = <double>[];
    var y = 0.0;
    for (final section in widget.sections) {
      offsets.add(y);
      final rows = (section.count / _columns).ceil();
      y += SectionedGrid.titleHeight + rows * widget.cellExtent;
    }
    return offsets;
  }

  void _jumpTo(int section) {
    if (!_scroll.hasClients || section >= widget.sections.length) return;
    final target = _offsets()[section];
    _scroll.jumpTo(math.min(target, _scroll.position.maxScrollExtent));
    _setCurrent(section);
  }

  void _report() {
    final offsets = _offsets();
    final y = _scroll.offset + 1;
    var section = 0;
    for (var i = 0; i < offsets.length; i++) {
      if (offsets[i] <= y) section = i;
    }
    // At the very end, a short last section never reaches the top.
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 1) {
      section = offsets.length - 1;
    }
    _setCurrent(section);
  }

  void _setCurrent(int section) {
    if (section == _current) return;
    _current = section;
    widget.onSection?.call(section);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 2 * SectionedGrid.padding;
        _columns = math.max(1, width ~/ widget.cellExtent);
        return CustomScrollView(
          controller: _scroll,
          slivers: [
            for (final section in widget.sections) ...[
              SliverToBoxAdapter(
                child: Container(
                  height: SectionedGrid.titleHeight,
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.fromLTRB(
                    MgSpace.l,
                    0,
                    MgSpace.l,
                    MgSpace.xs,
                  ),
                  child: Text(
                    section.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(
                      c,
                      size: MgType.caption,
                      weight: FontWeight.w500,
                      color: c.fg2,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SectionedGrid.padding,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns,
                    mainAxisExtent: widget.cellExtent,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    section.builder,
                    childCount: section.count,
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: MgSpace.s)),
          ],
        );
      },
    );
  }
}

/// The row of section buttons under a panel tab.
class PanelSectionBar extends StatelessWidget {
  const PanelSectionBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.labels = const [],
  });

  /// One icon (or small picture) per section.
  final List<Widget> items;

  /// Accessible names of [items], when they have one.
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.separator, width: 0.5)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: MgSpace.s,
          vertical: MgSpace.xs,
        ),
        children: [
          for (final (i, item) in items.indexed)
            _SectionButton(
              selected: i == selected,
              label: i < labels.length ? labels[i] : null,
              onTap: () => onSelect(i),
              child: item,
            ),
        ],
      ),
    );
  }
}

class _SectionButton extends StatefulWidget {
  const _SectionButton({
    required this.selected,
    required this.onTap,
    required this.child,
    this.label,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String? label;

  @override
  State<_SectionButton> createState() => _SectionButtonState();
}

class _SectionButtonState extends State<_SectionButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final button = Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.selected
                  ? c.field
                  : _hover
                  ? c.hover
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(MgRadius.small),
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: widget.selected ? c.fg : c.fg2),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
    final label = widget.label;
    return label == null
        ? button
        : Tooltip(
            message: label,
            waitDuration: const Duration(milliseconds: 600),
            child: button,
          );
  }
}

/// A cell that lights up under the pointer and reacts to a click.
class PanelCell extends StatefulWidget {
  const PanelCell({
    super.key,
    required this.onTap,
    required this.child,
    this.label,
    this.onHover,
  });

  final VoidCallback onTap;
  final Widget child;
  final String? label;

  /// Whether the pointer is over the cell, for stickers that play then.
  final ValueChanged<bool>? onHover;

  @override
  State<PanelCell> createState() => _PanelCellState();
}

class _PanelCellState extends State<PanelCell> {
  var _hover = false;

  void _set(bool hover) {
    setState(() => _hover = hover);
    widget.onHover?.call(hover);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: widget.label != null,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _set(true),
        onExit: (_) => _set(false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.all(1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? c.hover : const Color(0x00000000),
              borderRadius: BorderRadius.circular(MgRadius.control),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// What the emoji tab says, localized by the app.
final class EmojiTabLabels {
  const EmojiTabLabels({
    required this.search,
    required this.recent,
    required this.noResults,
    required this.groups,
  });

  final String search;
  final String recent;
  final String noResults;

  /// A title for every [EmojiGroup].
  final Map<EmojiGroup, String> groups;
}

/// The emoji tab: a search field, recent emoji and every group, and a bar
/// to jump between them. Picking an emoji calls [onPick] and leaves the
/// panel open, as in the official apps.
class EmojiTab extends StatefulWidget {
  const EmojiTab({
    super.key,
    required this.labels,
    required this.onPick,
    this.recent = const [],
    this.search,
  });

  final EmojiTabLabels labels;
  final ValueChanged<String> onPick;
  final List<String> recent;

  /// Emoji for a query from Telegram's keywords, in the user's language.
  /// Matches on the English names show until it answers, or without it.
  final Future<List<String>> Function(String query)? search;

  static const double cellExtent = 36;

  static const Map<EmojiGroup, MgIconData> icons = {
    EmojiGroup.smileys: MgIcons.emoji,
    EmojiGroup.people: MgIcons.profile,
    EmojiGroup.animals: MgIcons.animals,
    EmojiGroup.food: MgIcons.food,
    EmojiGroup.travel: MgIcons.travel,
    EmojiGroup.activities: MgIcons.activities,
    EmojiGroup.objects: MgIcons.objects,
    EmojiGroup.symbols: MgIcons.symbols,
    EmojiGroup.flags: MgIcons.flag,
  };

  /// Emoji whose English name has every word of [query] in it.
  static List<String> matchNames(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((word) => word.isEmpty);
    if (words.isEmpty) return const [];
    return [
      for (final group in emojiByGroup.values)
        for (final (emoji, name) in group)
          if (words.every(name.toLowerCase().contains)) emoji,
    ];
  }

  @override
  State<EmojiTab> createState() => _EmojiTabState();
}

class _EmojiTabState extends State<EmojiTab> {
  final _grid = SectionedGridController();
  final _query = TextEditingController();
  var _section = 0;
  List<String>? _found;
  var _searchId = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final id = ++_searchId;
    final text = query.trim();
    if (text.isEmpty) {
      setState(() {
        _found = null;
        _section = 0;
      });
      return;
    }
    final local = EmojiTab.matchNames(text);
    setState(() => _found = local);
    final search = widget.search;
    if (search == null) return;
    List<String> remote;
    try {
      remote = await search(text);
    } on Object {
      return;
    }
    if (!mounted || id != _searchId) return;
    setState(() => _found = {...remote, ...local}.toList());
  }

  Widget _cell(String emoji) => PanelCell(
    label: emoji,
    onTap: () => widget.onPick(emoji),
    child: Text(emoji, style: const TextStyle(fontSize: 24, height: 1.15)),
  );

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l = widget.labels;
    final found = _found;
    final groups = EmojiGroup.values;
    final hasRecent = widget.recent.isNotEmpty;
    final sections = found != null
        ? [
            if (found.isNotEmpty)
              GridSection(
                title: l.search,
                count: found.length,
                builder: (context, i) => _cell(found[i]),
              ),
          ]
        : [
            if (hasRecent)
              GridSection(
                title: l.recent,
                count: widget.recent.length,
                builder: (context, i) => _cell(widget.recent[i]),
              ),
            for (final group in groups)
              GridSection(
                title: l.groups[group] ?? group.name,
                count: emojiByGroup[group]!.length,
                builder: (context, i) => _cell(emojiByGroup[group]![i].$1),
              ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MgSpace.ml,
            MgSpace.xs,
            MgSpace.ml,
            0,
          ),
          child: MgSearchField(
            hintText: l.search,
            controller: _query,
            onChanged: (value) => unawaited(_search(value)),
            onSubmitted: (_) {
              if (found != null && found.isNotEmpty) widget.onPick(found[0]);
            },
          ),
        ),
        Expanded(
          child: found != null && found.isEmpty
              ? Center(
                  child: Text(l.noResults, style: mgTextStyle(c, color: c.fg2)),
                )
              : SectionedGrid(
                  // A new key starts search results at the top.
                  key: ValueKey(found == null),
                  sections: sections,
                  cellExtent: EmojiTab.cellExtent,
                  controller: _grid,
                  onSection: (section) => setState(() => _section = section),
                ),
        ),
        if (found == null)
          PanelSectionBar(
            selected: _section,
            labels: [
              if (hasRecent) l.recent,
              for (final group in groups) l.groups[group] ?? group.name,
            ],
            items: [
              if (hasRecent) const MgIcon(MgIcons.recent, size: 17),
              for (final group in groups)
                MgIcon(EmojiTab.icons[group]!, size: 17),
            ],
            onSelect: _grid.jumpTo,
          ),
      ],
    );
  }
}
