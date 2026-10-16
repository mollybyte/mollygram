import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../../chat/media_content.dart';
import '../../session/providers.dart';
import '../settings_style.dart';

/// What became of looking up a set for [showStickerSetSheet].
enum StickerSetLookup {
  /// The sheet was shown and has closed.
  shown,

  /// Telegram has no set by that name.
  notFound,

  /// The request failed, as without a connection.
  failed,
}

/// Looks up the set named [name], as `t.me/addstickers/<name>` or
/// `tg://addstickers?set=<name>` give it, and shows it in a sheet with Add
/// or Remove. [onInstalled] hears each Add or Remove made in the sheet.
Future<StickerSetLookup> showStickerSetSheet(
  BuildContext context,
  String name, {
  ValueChanged<bool>? onInstalled,
}) async {
  final td.StickerSet set;
  try {
    final session = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(telegramSessionProvider).requireValue;
    set = await session.stickerSets.byName(name);
  } on td.TdException catch (e) {
    // TDLib answers 400 STICKERSET_INVALID for a name with no set.
    return e.code == 400 ? StickerSetLookup.notFound : StickerSetLookup.failed;
  } on Object {
    return StickerSetLookup.failed;
  }
  if (!context.mounted) return StickerSetLookup.shown;
  await showMgSheet<void>(
    context,
    StickerSetSheet(set: set, onInstalled: onInstalled),
  );
  return StickerSetLookup.shown;
}

/// Shows the set with [setId] in the same sheet, as a tap on a sticker in
/// a chat asks for it. Nothing opens when the set can't be fetched.
Future<void> showStickerSetSheetById(BuildContext context, int setId) async {
  final td.StickerSet set;
  try {
    final session = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(telegramSessionProvider).requireValue;
    set = await session.stickerSets.byId(setId);
  } on Object {
    return;
  }
  if (!context.mounted) return;
  await showMgSheet<void>(context, StickerSetSheet(set: set));
}

/// A set's stickers in a grid, animated under the pointer, and the button
/// that adds or removes the set.
class StickerSetSheet extends ConsumerStatefulWidget {
  const StickerSetSheet({super.key, required this.set, this.onInstalled});

  final td.StickerSet set;

  /// Hears each Add (true) or Remove (false) made here.
  final ValueChanged<bool>? onInstalled;

  @override
  ConsumerState<StickerSetSheet> createState() => _StickerSetSheetState();
}

class _StickerSetSheetState extends ConsumerState<StickerSetSheet> {
  late var _installed = widget.set.isInstalled;
  var _saving = false;
  var _failed = false;

  bool get _emoji => widget.set.stickerType is td.StickerTypeCustomEmoji;

  void _close() => Navigator.of(context).pop();

  Future<void> _toggle() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final sets = ref.read(telegramSessionProvider).requireValue.stickerSets;
    final set = widget.set;
    final kind = StickerSetKind.of(set.stickerType);
    try {
      if (_installed) {
        await sets.remove(_infoOf(set));
      } else {
        await sets.install(set.id, kind);
      }
      widget.onInstalled?.call(!_installed);
      if (!mounted) return;
      setState(() {
        _installed = !_installed;
        _saving = false;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final set = widget.set;
    final count = _emoji
        ? l10n.emojiCount(set.stickers.length)
        : l10n.stickerCount(set.stickers.length);
    final side = _emoji ? 40.0 : 72.0;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: 420,
          height: 520,
          child: Glass(
            radius: MgRadius.popover,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              set.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(c, weight: FontWeight.w600),
                            ),
                            Text(
                              count,
                              style: mgTextStyle(
                                c,
                                size: MgType.caption,
                                color: c.fg2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MgIconButton(
                        icon: MgIcons.close,
                        tooltip: l10n.close,
                        onPressed: _close,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: side + 16,
                    ),
                    itemCount: set.stickers.length,
                    itemBuilder: (context, i) => _Cell(
                      key: ValueKey(set.stickers[i].id),
                      sticker: set.stickers[i],
                      side: side,
                    ),
                  ),
                ),
                Container(height: 0.5, color: c.separator),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_failed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            l10n.saveFailed,
                            textAlign: TextAlign.center,
                            style: mgTextStyle(
                              c,
                              size: MgType.caption,
                              color: MgDestructive.color,
                            ),
                          ),
                        ),
                      MgPrimaryButton(
                        key: const ValueKey('toggleSet'),
                        label: _installed ? l10n.remove : l10n.addSet,
                        loading: _saving,
                        expand: true,
                        onPressed: _saving ? null : () => unawaited(_toggle()),
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

/// The set as a list row of it would describe it, for removing.
td.StickerSetInfo _infoOf(td.StickerSet set) => td.StickerSetInfo(
  id: set.id,
  title: set.title,
  name: set.name,
  thumbnail: set.thumbnail,
  thumbnailOutline: set.thumbnailOutline,
  isOwned: set.isOwned,
  isInstalled: set.isInstalled,
  isArchived: set.isArchived,
  isOfficial: set.isOfficial,
  stickerType: set.stickerType,
  needsRepainting: set.needsRepainting,
  isAllowedAsChatEmojiStatus: set.isAllowedAsChatEmojiStatus,
  isViewed: set.isViewed,
  size: set.stickers.length,
  covers: const [],
);

/// A sticker that plays once the pointer has rested on it for a moment,
/// showing its still until then, so a page of cells doesn't decode every
/// animation. With reduced motion it stays still.
class _Cell extends StatefulWidget {
  const _Cell({super.key, required this.sticker, required this.side});

  final td.Sticker sticker;
  final double side;

  /// How long the pointer rests before the sticker plays.
  static const playDelay = Duration(milliseconds: 80);

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  var _hover = false;
  var _play = false;
  Timer? _timer;

  void _enter() {
    setState(() => _hover = true);
    _timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) return;
    _timer = Timer(_Cell.playDelay, () {
      if (mounted && _hover) setState(() => _play = true);
    });
  }

  void _exit() {
    _timer?.cancel();
    setState(() {
      _hover = false;
      _play = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final play = _play && !MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) => _enter(),
      onExit: (_) => _exit(),
      child: AnimatedContainer(
        duration: settingsMotionOf(context),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _hover ? c.hover : const Color(0x00000000),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: StickerContent(
          sticker: widget.sticker,
          side: widget.side,
          animate: play,
          lazy: true,
        ),
      ),
    );
  }
}
