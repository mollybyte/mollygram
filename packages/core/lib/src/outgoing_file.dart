import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// How a file is sent: compressed as a photo or a video, as a looping
/// animation, as music, or untouched as a document.
enum OutgoingKind { photo, video, animation, audio, document }

/// A local file the user chose to send.
final class OutgoingFile {
  const OutgoingFile({
    required this.path,
    required this.kind,
    this.width = 0,
    this.height = 0,
    this.duration = 0,
    this.forceFile = false,
    this.spoiler = false,
    this.selfDestruct = 0,
    this.thumbnail,
    this.cover,
    this.alone = false,
  });

  /// [selfDestruct] for a photo or video that goes away once viewed.
  static const viewOnce = -1;

  final String path;
  final OutgoingKind kind;

  /// Pixel size of photos and videos, when the app could read it; 0 lets
  /// TDLib and the server work it out.
  final int width;
  final int height;

  /// Seconds, for videos and music.
  final int duration;

  /// Sent as a plain file even when TDLib would recognise a video or a
  /// song in it.
  final bool forceFile;

  /// A photo, video or animation hidden behind a spoiler until tapped.
  final bool spoiler;

  /// Seconds after which a photo or video disappears once seen, in a
  /// private chat; 0 keeps it, [viewOnce] removes it after one viewing.
  final int selfDestruct;

  /// A small JPEG shown for a video before it downloads, at most 320 px
  /// a side; null lets TDLib make one.
  final String? thumbnail;

  /// A JPEG the user chose as the video's cover frame; null shows the
  /// first frame.
  final String? cover;

  /// Sent as its own message even beside other photos and videos, when
  /// the user turned album grouping off.
  final bool alone;

  OutgoingFile copyWith({
    String? path,
    OutgoingKind? kind,
    int? width,
    int? height,
    int? duration,
    bool? forceFile,
    bool? spoiler,
    int? selfDestruct,
    String? thumbnail,
    String? cover,
    bool? alone,
  }) => OutgoingFile(
    path: path ?? this.path,
    kind: kind ?? this.kind,
    width: width ?? this.width,
    height: height ?? this.height,
    duration: duration ?? this.duration,
    forceFile: forceFile ?? this.forceFile,
    spoiler: spoiler ?? this.spoiler,
    selfDestruct: selfDestruct ?? this.selfDestruct,
    thumbnail: thumbnail ?? this.thumbnail,
    cover: cover ?? this.cover,
    alone: alone ?? this.alone,
  );

  /// The same file, sent untouched.
  OutgoingFile asDocument() =>
      OutgoingFile(path: path, kind: OutgoingKind.document, forceFile: true);

  /// Photos and videos can be sent compressed or as files.
  bool get isMedia => kind == OutgoingKind.photo || kind == OutgoingKind.video;
}

// HEIC and BMP go as files: Telegram takes neither as a photo.
const _photo = {'jpg', 'jpeg', 'png', 'webp'};
// Telegram plays MPEG-4 with H.264 inline; WebM, MKV and AVI would need
// transcoding first, so they go as files.
const _video = {'mp4', 'mov', 'm4v'};
const _audio = {'mp3', 'm4a', 'aac', 'flac', 'ogg', 'oga', 'opus', 'wav'};

/// Whether Telegram takes a picture of [width] x [height] pixels and
/// [bytes] in size as a photo: at most 10 MB, width and height adding up
/// to at most 10000 and one side at most 20 times the other.
bool fitsAsPhoto({
  required int width,
  required int height,
  required int bytes,
}) {
  if (width <= 0 || height <= 0) return false;
  final ratio = width > height ? width / height : height / width;
  return bytes <= 10 * 1000 * 1000 && width + height <= 10000 && ratio <= 20;
}

/// The kind a file is sent as by default, from its extension, as the
/// official clients do.
OutgoingKind outgoingKindOf(String path) {
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf(RegExp(r'[/\\]'));
  if (dot < 0 || dot < slash) return OutgoingKind.document;
  final extension = path.substring(dot + 1).toLowerCase();
  if (_photo.contains(extension)) return OutgoingKind.photo;
  if (_video.contains(extension)) return OutgoingKind.video;
  if (extension == 'gif') return OutgoingKind.animation;
  if (_audio.contains(extension)) return OutgoingKind.audio;
  return OutgoingKind.document;
}

/// The files split into the messages and albums they are sent as: photos
/// and videos group together, documents and music each with their own
/// kind, at most ten per album; animations always go alone.
List<List<OutgoingFile>> groupForSending(List<OutgoingFile> files) {
  final groups = <List<OutgoingFile>>[];
  String? lastFamily;
  for (final file in files) {
    // Self-destructing media goes alone, as TDLib wants it.
    final family = switch (file.kind) {
      OutgoingKind.photo || OutgoingKind.video when file.alone => null,
      OutgoingKind.photo ||
      OutgoingKind.video when file.selfDestruct != 0 => null,
      OutgoingKind.photo || OutgoingKind.video => 'media',
      OutgoingKind.document => 'document',
      OutgoingKind.audio => 'audio',
      OutgoingKind.animation => null,
    };
    if (family == null ||
        family != lastFamily ||
        groups.isEmpty ||
        groups.last.length == 10) {
      groups.add([file]);
    } else {
      groups.last.add(file);
    }
    lastFamily = family;
  }
  return groups;
}

/// What TDLib sends for [file], with [caption] under it.
td.InputMessageContent inputContentOf(
  OutgoingFile file, {
  td.FormattedText? caption,
}) {
  final input = td.InputFileLocal(path: file.path);
  return switch (file.kind) {
    OutgoingKind.photo => td.InputMessagePhoto(
      photo: td.InputPhoto(
        photo: input,
        addedStickerFileIds: const [],
        width: file.width,
        height: file.height,
      ),
      caption: caption,
      showCaptionAboveMedia: false,
      selfDestructType: _selfDestructOf(file),
      hasSpoiler: file.spoiler,
    ),
    OutgoingKind.video => td.InputMessageVideo(
      video: td.InputVideo(
        video: input,
        thumbnail: file.thumbnail == null
            ? null
            : td.InputThumbnail(
                thumbnail: td.InputFileLocal(path: file.thumbnail!),
                width: 0,
                height: 0,
              ),
        cover: file.cover == null ? null : td.InputFileLocal(path: file.cover!),
        startTimestamp: 0,
        addedStickerFileIds: const [],
        duration: file.duration,
        width: file.width,
        height: file.height,
        supportsStreaming: true,
      ),
      caption: caption,
      showCaptionAboveMedia: false,
      selfDestructType: _selfDestructOf(file),
      hasSpoiler: file.spoiler,
    ),
    OutgoingKind.animation => td.InputMessageAnimation(
      animation: td.InputAnimation(
        animation: input,
        addedStickerFileIds: const [],
        duration: file.duration,
        width: file.width,
        height: file.height,
      ),
      caption: caption,
      showCaptionAboveMedia: false,
      hasSpoiler: file.spoiler,
    ),
    OutgoingKind.audio => td.InputMessageAudio(
      audio: td.InputAudio(
        audio: input,
        duration: file.duration,
        title: '',
        performer: '',
      ),
      caption: caption,
    ),
    OutgoingKind.document => td.InputMessageDocument(
      document: td.InputDocument(
        document: input,
        disableContentTypeDetection: file.forceFile,
      ),
      caption: caption,
    ),
  };
}

td.MessageSelfDestructType? _selfDestructOf(OutgoingFile file) =>
    switch (file.selfDestruct) {
      0 => null,
      OutgoingFile.viewOnce => const td.MessageSelfDestructTypeImmediately(),
      final seconds => td.MessageSelfDestructTypeTimer(
        selfDestructTime: seconds,
      ),
    };
