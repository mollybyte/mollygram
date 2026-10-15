import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import '../settings/storage_page.dart' show downloadFolderOf;

/// The file a message carries and the name to save it under: the name the
/// sender gave, or the kind and the time it was sent, as Telegram for
/// macOS names them. Null for a message with no file to save.
({td.File file, String name})? savableFileOf(td.Message message) {
  final stamp = DateFormat('yyyy-MM-dd HH.mm.ss')
      .format(DateTime.fromMillisecondsSinceEpoch(message.date * 1000));
  String named(String given, String kind) =>
      given.isNotEmpty ? given : '$kind $stamp';
  return switch (message.content) {
    td.MessageDocument(:final document) => (
      file: document.document,
      name: named(document.fileName, 'File'),
    ),
    td.MessagePhoto(:final photo) when photo.sizes.isNotEmpty => (
      file: photo.sizes.last.photo,
      name: 'Photo $stamp',
    ),
    td.MessageVideo(:final video) => (
      file: video.video,
      name: named(video.fileName, 'Video'),
    ),
    td.MessageAnimation(:final animation) => (
      file: animation.animation,
      name: named(animation.fileName, 'GIF'),
    ),
    td.MessageAudio(:final audio) => (
      file: audio.audio,
      name: named(
        audio.fileName.isNotEmpty
            ? audio.fileName
            : [
                audio.performer,
                audio.title,
              ].where((part) => part.isNotEmpty).join(' - '),
        'Audio',
      ),
    ),
    td.MessageVoiceNote(:final voiceNote) => (
      file: voiceNote.voice,
      name: 'Voice $stamp',
    ),
    td.MessageVideoNote(:final videoNote) => (
      file: videoNote.video,
      name: 'Video message $stamp',
    ),
    td.MessageSticker(:final sticker) => (
      file: sticker.sticker,
      name: 'Sticker $stamp',
    ),
    _ => null,
  };
}

/// Saves [file] as [name]: into the download folder when [toDownloads],
/// otherwise where a save panel says. A file not yet downloaded is fetched
/// first, as a download of the message in the downloads manager. Says how it went in a toast, unless the chat is gone
/// ([isShown]).
Future<void> saveMessageFile(
  BuildContext context, {
  required td.File file,
  required String name,
  required int chatId,
  required int messageId,
  required bool toDownloads,
  required bool Function() isShown,
}) async {
  final l10n = AppLocalizations.of(context);
  final session = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(telegramSessionProvider).requireValue;
  final folder = await downloadFolderOf(context);
  String? path = downloadedPath(file);
  if (path == null) {
    try {
      // Through the downloads list, so the manager shows it, then wait for
      // the whole file.
      await session.downloads.add(
        file.id,
        chatId: chatId,
        messageId: messageId,
      );
      path = downloadedPath(await session.files.downloadNow(file.id));
    } on td.TdException {
      path = null;
    }
  }
  if (!context.mounted || !isShown()) return;
  if (path == null) {
    showMgToast(context, l10n.mediaSaveFailed);
    return;
  }
  final fileName = _withExtension(name, path);
  final String target;
  if (toDownloads && folder != null) {
    target = _freePath(folder, fileName);
  } else {
    final location = await getSaveLocation(
      suggestedName: fileName,
      initialDirectory: folder,
    );
    if (location == null || !context.mounted || !isShown()) return;
    target = location.path;
  }
  try {
    await File(path).copy(target);
    if (context.mounted && isShown()) showMgToast(context, l10n.mediaSaved);
  } on FileSystemException {
    if (context.mounted && isShown()) {
      showMgToast(context, l10n.mediaSaveFailed);
    }
  }
}

/// [name] with the extension of [path] when it has none of its own.
String _withExtension(String name, String path) {
  final base = path.split(Platform.pathSeparator).last;
  final dot = base.lastIndexOf('.');
  if (dot <= 0 || name.split('/').last.contains('.')) return name;
  return '$name${base.substring(dot)}';
}

/// "name.ext" in [folder], or "name 2.ext" and on when it is taken.
String _freePath(String folder, String name) {
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final extension = dot > 0 ? name.substring(dot) : '';
  var candidate = '$folder${Platform.pathSeparator}$name';
  for (var n = 2; File(candidate).existsSync(); n++) {
    candidate = '$folder${Platform.pathSeparator}$stem $n$extension';
  }
  return candidate;
}

/// Shows [path] selected in the system's file manager: Finder on macOS,
/// Explorer on Windows, the folder on Linux. Swapped in tests.
Future<void> Function(String path) revealFile = _revealWithSystem;

Future<void> _revealWithSystem(String path) async {
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', path]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', ['/select,$path']);
  } else {
    await Process.run('xdg-open', [File(path).parent.path]);
  }
}

/// Previews [path] with Quick Look, as a click on a file does in Telegram
/// for macOS. Swapped in tests.
Future<void> Function(String path) quickLookFile = _quickLookWithSystem;

Future<void> _quickLookWithSystem(String path) async {
  await Process.run('qlmanage', ['-p', path]);
}
