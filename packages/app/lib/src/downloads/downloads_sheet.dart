import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart' show primaryShortcut;
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../chat/save_file.dart' show quickLookFile, revealFile, savableFileOf;
import '../home/workspace.dart';
import '../session/providers.dart';
import '../settings/storage_page.dart' show formatBytes;
import 'downloads_providers.dart';

/// Opens the downloads over the window, as the people sheet opens.
Future<void> showDownloadsSheet(BuildContext context) =>
    showMgSheet<void>(context, const DownloadsSheet());

/// The downloads: active ones first with their progress, then paused and
/// finished ones. A row pauses or resumes its download; a finished one
/// opens the file, and its menu shows it in Finder, opens its chat or
/// takes it off the list.
class DownloadsSheet extends ConsumerWidget {
  const DownloadsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(telegramSessionProvider).value;
    if (session == null) return const SizedBox.shrink();
    final downloads = session.downloads;
    final entries = ref.watch(downloadsProvider).value ?? const [];
    final counts =
        ref.watch(downloadCountsProvider).value ?? const DownloadCounts();
    final unfinished = counts.active + counts.paused;
    final allPaused = unfinished > 0 && counts.active == 0;

    return SizedBox(
      width: 400,
      height: 480,
      child: Glass(
        radius: MgRadius.popover,
        padding: const EdgeInsets.fromLTRB(
          MgSpace.ml,
          MgSpace.m,
          MgSpace.ml,
          MgSpace.ml,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.downloads,
                      style: mgTextStyle(c, weight: FontWeight.w600),
                    ),
                  ),
                  if (unfinished > 0)
                    MgTextButton(
                      key: const ValueKey('downloads.pauseAll'),
                      label: allPaused ? l10n.resumeAll : l10n.pauseAll,
                      onPressed: () => unawaited(
                        allPaused
                            ? downloads.resumeAll()
                            : downloads.pauseAll(),
                      ),
                    ),
                  if (counts.completed > 0)
                    MgTextButton(
                      key: const ValueKey('downloads.clear'),
                      label: l10n.clearFinished,
                      onPressed: () => unawaited(downloads.clear()),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: entries.isEmpty
                  ? _Empty(
                      title: l10n.downloadsEmpty,
                      hint: l10n.downloadsEmptyHint,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: entries.length,
                      itemBuilder: (context, i) => _DownloadRow(
                        key: ValueKey(entries[i].fileId),
                        entry: entries[i],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MgIcon(
            MgIcons.download,
            size: 28,
            color: c.fg2.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(title, style: mgTextStyle(c, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: mgTextStyle(c, size: MgType.small, color: c.fg2),
          ),
        ],
      ),
    );
  }
}

/// One download: a kind icon with the progress ring, the name, the chat
/// and the size or progress, and the hover actions.
class _DownloadRow extends ConsumerStatefulWidget {
  const _DownloadRow({super.key, required this.entry});

  final DownloadEntry entry;

  @override
  ConsumerState<_DownloadRow> createState() => _DownloadRowState();
}

class _DownloadRowState extends ConsumerState<_DownloadRow> {
  var _hover = false;

  DownloadEntry get entry => widget.entry;

  DownloadsController get _downloads =>
      ref.read(telegramSessionProvider).requireValue.downloads;

  String? get _path => downloadedPath(entry.file);

  Future<void> _primary() async {
    if (entry.isCompleted) {
      final path = _path;
      if (path != null) await quickLookFile(path);
    } else if (entry.isPaused) {
      await _downloads.resume(entry.fileId);
    } else {
      await _downloads.pause(entry.fileId);
    }
  }

  void _openChat() {
    ref.read(workspaceControllerProvider).open(entry.chatId);
    Navigator.of(context).pop();
  }

  Future<void> _menu(Offset position) async {
    final l10n = AppLocalizations.of(context);
    final path = _path;
    await showMgMenu(
      context,
      position: position,
      items: [
        if (path != null) ...[
          MgMenuItem(
            label: l10n.openFile,
            icon: MgIcons.file,
            onSelected: () => unawaited(quickLookFile(path)),
          ),
          MgMenuItem(
            label: l10n.menuShowInFinder,
            icon: MgIcons.folder,
            onSelected: () => unawaited(revealFile(path)),
          ),
        ] else
          MgMenuItem(
            label: entry.isPaused ? l10n.resume : l10n.pause,
            icon: entry.isPaused ? MgIcons.play : MgIcons.pause,
            onSelected: () => unawaited(_primary()),
          ),
        MgMenuItem(
          label: l10n.showInChat,
          icon: MgIcons.chat,
          onSelected: _openChat,
        ),
        MgMenuItem(
          label: l10n.removeFromList,
          icon: MgIcons.close,
          destructive: true,
          onSelected: () => unawaited(_downloads.remove(entry.fileId)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final chat = ref.watch(chatEntryProvider(entry.chatId)).value;
    final name = savableFileOf(entry.message)?.name ?? '';
    final total = formatBytes(entry.expectedSize, l10n, locale);
    final subtitle = entry.isCompleted
        ? [total, ?chat?.title].join(' · ')
        : entry.isPaused
        ? [l10n.downloadPaused, total].join(' · ')
        : l10n.downloadProgress(
            formatBytes(entry.downloadedSize, l10n, locale),
            total,
          );
    final icon = entry.isCompleted
        ? _kindIcon(entry.message.content)
        : entry.isPaused
        ? MgIcons.play
        : MgIcons.pause;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (d) => unawaited(_menu(d.globalPosition)),
        onDoubleTap: entry.isCompleted ? () => unawaited(_primary()) : null,
        child: AnimatedContainer(
          duration: MgMotion.fast,
          padding: const EdgeInsets.all(MgSpace.s),
          decoration: BoxDecoration(
            color: _hover ? c.hover : const Color(0x00000000),
            borderRadius: BorderRadius.circular(MgRadius.control),
          ),
          child: Row(
            children: [
              MediaActionButton(
                key: ValueKey('download.${entry.fileId}.action'),
                icon: icon,
                size: 34,
                progress: entry.isCompleted ? null : entry.progress,
                background: entry.isCompleted
                    ? c.fg2.withValues(alpha: 0.35)
                    : null,
                semanticLabel: entry.isCompleted
                    ? l10n.openFile
                    : entry.isPaused
                    ? l10n.resume
                    : l10n.pause,
                onTap: () => unawaited(_primary()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(c, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(c, size: MgType.meta, color: c.fg2),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: MgMotion.fast,
                opacity: _hover ? 1 : 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_path != null)
                      MgIconButton(
                        key: ValueKey('download.${entry.fileId}.reveal'),
                        icon: MgIcons.file,
                        tooltip: l10n.menuShowInFinder,
                        iconSize: 15,
                        onPressed: () => unawaited(revealFile(_path!)),
                      ),
                    MgIconButton(
                      key: ValueKey('download.${entry.fileId}.remove'),
                      icon: MgIcons.close,
                      tooltip: l10n.removeFromList,
                      iconSize: 14,
                      onPressed: () =>
                          unawaited(_downloads.remove(entry.fileId)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

MgIconData _kindIcon(td.MessageContent content) => switch (content) {
  td.MessagePhoto() => MgIcons.camera,
  td.MessageVideo() ||
  td.MessageVideoNote() ||
  td.MessageAnimation() => MgIcons.video,
  td.MessageAudio() || td.MessageVoiceNote() => MgIcons.volume,
  td.MessageSticker() => MgIcons.sticker,
  _ => MgIcons.file,
};

/// Keyboard shortcut of the downloads command: ⌘⇧J (Ctrl+Shift+J off
/// macOS), as browsers open their downloads.
SingleActivator get downloadsShortcut =>
    primaryShortcut(LogicalKeyboardKey.keyJ, shift: true);
