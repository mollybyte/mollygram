import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../chat/td_file.dart';

/// A chat's or user's round avatar, anywhere outside the message list.
///
/// The photo downloads when the avatar is first built (so in a lazy list,
/// when its row scrolls into view) at preview priority, and TDLib keeps the
/// file, so a row scrolled back to draws it from the image cache at once.
/// Until the bytes are there, the blurred minithumbnail stands in; a chat
/// without a photo gets the gray monogram.
class PeerAvatar extends StatelessWidget {
  const PeerAvatar({
    super.key,
    required this.name,
    required this.size,
    this.photo,
    this.minithumbnail,
  });

  /// The avatar of a chat, from the photo TDLib sends with it.
  PeerAvatar.chat({
    super.key,
    required this.name,
    required this.size,
    td.ChatPhotoInfo? photo,
  }) : photo = photo?.small,
       minithumbnail = photo?.minithumbnail;

  final String name;
  final double size;

  /// The small (160 px) photo file.
  final td.File? photo;
  final td.Minithumbnail? minithumbnail;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    if (photo == null) return MonogramAvatar(name: name, size: size);
    final mini = minithumbnail;
    final placeholder = mini == null ? null : MemoryImage(mini.data);
    return TdFileBuilder(
      file: photo,
      download: true,
      priority: DownloadPriority.preview,
      builder: (context, file) {
        final path = downloadedPath(file);
        return MonogramAvatar(
          name: name,
          size: size,
          placeholder: placeholder,
          image: path == null
              ? null
              : ResizeImage(
                  FileImage(File(path)),
                  width: (size * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                ),
        );
      },
    );
  }
}
