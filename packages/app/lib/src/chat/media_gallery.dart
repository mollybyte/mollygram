import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// A photo, video or GIF the media viewer shows.
sealed class MediaViewerItem {
  const MediaViewerItem();

  const factory MediaViewerItem.photo(td.Photo photo) = PhotoItem;
  const factory MediaViewerItem.video(td.Video video) = VideoItem;
  const factory MediaViewerItem.animation(td.Animation animation) =
      AnimationItem;

  /// The item in a message, when it has one.
  static MediaViewerItem? of(td.MessageContent content) => switch (content) {
    td.MessagePhoto(:final photo) => PhotoItem(photo),
    td.MessageVideo(:final video) => VideoItem(video),
    td.MessageAnimation(:final animation) => AnimationItem(animation),
    _ => null,
  };
}

final class PhotoItem extends MediaViewerItem {
  const PhotoItem(this.photo);
  final td.Photo photo;
}

final class VideoItem extends MediaViewerItem {
  const VideoItem(this.video);
  final td.Video video;
}

final class AnimationItem extends MediaViewerItem {
  const AnimationItem(this.animation);
  final td.Animation animation;
}

/// One page of the viewer, and the message it came from when it has one.
@immutable
final class GalleryEntry {
  const GalleryEntry(this.item, {this.message, this.date});

  final MediaViewerItem item;
  final ConversationMessage? message;

  /// When the media was set, for an entry with no message, such as a
  /// profile photo; Unix seconds.
  final int? date;
}

/// Loads photos and videos of a chat around a message, oldest first; see
/// [ConversationController.mediaAround].
typedef MediaLoader = Future<List<ConversationMessage>> Function(
  int fromMessageId, {
  int newer,
  int limit,
});

/// The pages of the media viewer: the chat's photos and videos in order,
/// loaded in pages as the user gets near either end, the way the official
/// app lets you page through a chat's media from any of them.
final class MediaGallery extends ChangeNotifier {
  /// Just [item], with nothing to page to.
  MediaGallery.single(MediaViewerItem item, {ConversationMessage? message})
    : _load = null,
      _entries = [GalleryEntry(item, message: message)],
      _olderEnd = true,
      _newerEnd = true;

  /// A fixed set of [entries], open at [index], with nothing to load.
  MediaGallery.list(List<GalleryEntry> entries, {int index = 0})
    : _load = null,
      _entries = entries,
      _olderEnd = true,
      _newerEnd = true {
    _index = index;
  }

  /// [start]'s media and, once [load] answers, the chat's around it. A GIF
  /// stays on its own, as TDLib's photo and video search leaves GIFs out.
  MediaGallery.chat(ConversationMessage start, {required MediaLoader load})
    : _load = MediaViewerItem.of(start.content) is AnimationItem ? null : load,
      _entries = [
        GalleryEntry(MediaViewerItem.of(start.content)!, message: start),
      ] {
    if (_load == null) {
      _olderEnd = true;
      _newerEnd = true;
    }
  }

  final MediaLoader? _load;
  List<GalleryEntry> _entries;
  var _index = 0;
  var _olderEnd = false;
  var _newerEnd = false;
  var _loadingOlder = false;
  var _loadingNewer = false;
  var _disposed = false;

  static const _page = 30;

  List<GalleryEntry> get entries => _entries;
  int get index => _index;
  GalleryEntry get current => _entries[_index];
  bool get hasPrevious => _index > 0;
  bool get hasNext => _index < _entries.length - 1;

  /// Asks for the media on both sides of the first page.
  Future<void> start() async {
    final load = _load;
    final from = current.message;
    if (load == null || from == null) return;
    final List<ConversationMessage> found;
    try {
      found = await load(from.id, newer: _page ~/ 2, limit: _page + 1);
    } on Object {
      _olderEnd = _newerEnd = true;
      return;
    }
    final older = found.where((m) => m.id < from.id).length;
    final newer = found.where((m) => m.id > from.id).length;
    _olderEnd = older < _page ~/ 2;
    _newerEnd = newer < _page ~/ 2;
    _merge(found);
  }

  /// Goes [delta] pages on, and loads more when that comes near an end.
  void go(int delta) {
    final target = (_index + delta).clamp(0, _entries.length - 1);
    if (target == _index) return;
    _index = target;
    _notify();
    _maybeLoad();
  }

  void _maybeLoad() {
    if (_index < 4) unawaited(_loadOlder());
    if (_index > _entries.length - 5) unawaited(_loadNewer());
  }

  Future<void> _loadOlder() async {
    final load = _load;
    final oldest = _entries.first.message;
    if (load == null || oldest == null || _olderEnd || _loadingOlder) return;
    _loadingOlder = true;
    try {
      final found = await load(oldest.id, limit: _page + 1);
      _olderEnd = found.where((m) => m.id < oldest.id).length < _page;
      _merge(found);
    } on Object {
      _olderEnd = true;
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> _loadNewer() async {
    final load = _load;
    final newest = _entries.last.message;
    if (load == null || newest == null || _newerEnd || _loadingNewer) return;
    _loadingNewer = true;
    try {
      final found = await load(newest.id, newer: _page, limit: _page + 1);
      _newerEnd = found.where((m) => m.id > newest.id).length < _page;
      _merge(found);
    } on Object {
      _newerEnd = true;
    } finally {
      _loadingNewer = false;
    }
  }

  /// Adds [found] in order, keeping the page the user is on.
  void _merge(List<ConversationMessage> found) {
    if (_disposed) return;
    final currentId = current.message?.id;
    final byId = <int, GalleryEntry>{
      for (final entry in _entries) entry.message!.id: entry,
    };
    for (final message in found) {
      final item = MediaViewerItem.of(message.content);
      if (item == null) continue;
      byId[message.id] = GalleryEntry(item, message: message);
    }
    final ids = byId.keys.toList()..sort();
    _entries = [for (final id in ids) byId[id]!];
    _index = currentId == null ? 0 : ids.indexOf(currentId);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
