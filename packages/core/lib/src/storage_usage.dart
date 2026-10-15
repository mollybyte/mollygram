import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// The kinds of cached files the storage settings show and clear.
enum StorageCategory { photos, videos, files, voiceAndMusic, stickers, other }

/// The category a TDLib file type is counted in, or null for files that
/// are not a cache: Telegram Passport documents and the user's own
/// notification sounds are never shown as clearable.
StorageCategory? storageCategoryOf(td.FileType type) => switch (type) {
  td.FileTypePhoto() || td.FileTypePhotoStory() => StorageCategory.photos,
  td.FileTypeVideo() ||
  td.FileTypeVideoNote() ||
  td.FileTypeVideoStory() ||
  td.FileTypeAnimation() ||
  td.FileTypeLivePhotoVideo() => StorageCategory.videos,
  td.FileTypeDocument() => StorageCategory.files,
  td.FileTypeAudio() || td.FileTypeVoiceNote() => StorageCategory.voiceAndMusic,
  td.FileTypeSticker() => StorageCategory.stickers,
  td.FileTypeSecure() || td.FileTypeNotificationSound() => null,
  _ => StorageCategory.other,
};

/// The TDLib file types cleared for [category].
List<td.FileType> fileTypesOf(StorageCategory category) => switch (category) {
  StorageCategory.photos => const [td.FileTypePhoto(), td.FileTypePhotoStory()],
  StorageCategory.videos => const [
    td.FileTypeVideo(),
    td.FileTypeVideoNote(),
    td.FileTypeVideoStory(),
    td.FileTypeAnimation(),
    td.FileTypeLivePhotoVideo(),
  ],
  StorageCategory.files => const [td.FileTypeDocument()],
  StorageCategory.voiceAndMusic => const [
    td.FileTypeAudio(),
    td.FileTypeVoiceNote(),
  ],
  StorageCategory.stickers => const [td.FileTypeSticker()],
  StorageCategory.other => const [
    td.FileTypeThumbnail(),
    td.FileTypeProfilePhoto(),
    td.FileTypeWallpaper(),
    td.FileTypeUnknown(),
    td.FileTypeNone(),
    td.FileTypeSecret(),
    td.FileTypeSecretThumbnail(),
    td.FileTypeSelfDestructingPhoto(),
    td.FileTypeSelfDestructingVideo(),
    td.FileTypeSelfDestructingVideoNote(),
    td.FileTypeSelfDestructingVoiceNote(),
    td.FileTypeSelfDestructingLivePhotoVideo(),
  ],
};

/// How much disk the account's cache takes, in bytes.
final class StorageUsage {
  const StorageUsage({required this.sizes, required this.databaseSize});

  /// Cached files by category; categories with nothing cached are absent.
  final Map<StorageCategory, int> sizes;

  /// The messages database, which clearing the cache leaves alone.
  final int databaseSize;

  int sizeOf(StorageCategory category) => sizes[category] ?? 0;

  /// All cached files together.
  int get filesSize => sizes.values.fold(0, (sum, size) => sum + size);

  /// Sums TDLib's per-chat statistics into categories.
  factory StorageUsage.from(
    td.StorageStatistics statistics, {
    int databaseSize = 0,
  }) {
    final sizes = <StorageCategory, int>{};
    for (final chat in statistics.byChat) {
      for (final entry in chat.byFileType) {
        final category = storageCategoryOf(entry.fileType);
        if (category == null || entry.size <= 0) continue;
        sizes[category] = (sizes[category] ?? 0) + entry.size;
      }
    }
    return StorageUsage(sizes: sizes, databaseSize: databaseSize);
  }
}

/// Reads and clears the account's file cache.
final class StorageManager {
  StorageManager(this._client);

  final td.TdClient _client;

  Future<StorageUsage> usage() async {
    // The chat limit only decides how many chats get their own entry; the
    // rest are summed into one, which is all the categories need.
    final full = await _client.send(
      const td.GetStorageStatistics(chatLimit: 1),
    );
    final fast = await _client.send(const td.GetStorageStatisticsFast());
    return StorageUsage.from(full, databaseSize: fast.databaseSize);
  }

  /// Deletes every cached file of [categories]. Files download again when
  /// a message that needs them is shown.
  Future<void> clear(Set<StorageCategory> categories) async {
    if (categories.isEmpty) return;
    await _client.send(
      td.OptimizeStorage(
        size: 0,
        ttl: 0,
        count: 0,
        immunityDelay: 0,
        fileTypes: [for (final c in categories) ...fileTypesOf(c)],
        chatIds: const [],
        excludeChatIds: const [],
        returnDeletedFileStatistics: false,
        chatLimit: 0,
      ),
    );
  }
}
