import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import 'preferences.dart';
import 'settings_style.dart';

/// The account's cache by kind of file. Read again after a clear.
final storageUsageProvider = FutureProvider.autoDispose<StorageUsage>(
  (ref) => ref.watch(telegramSessionProvider).requireValue.storage.usage(),
);

/// The folder saved files go to: the chosen one, or the system Downloads
/// folder. Null while it is looked up, or when the system has none.
final downloadFolderProvider = FutureProvider<String?>((ref) async {
  final chosen = ref.watch(preferencesProvider.select((p) => p.downloadFolder));
  if (chosen != null) return chosen;
  return (await getDownloadsDirectory())?.path;
});

/// The download folder, for save panels outside the settings (the media
/// viewer's Save). Null without a [ProviderScope] or a known folder.
Future<String?> downloadFolderOf(BuildContext context) async {
  try {
    return await ProviderScope.containerOf(
      context,
      listen: false,
    ).read(downloadFolderProvider.future);
  } on Object {
    return null;
  }
}

/// A size the way Finder writes it: decimal units, one decimal below 10
/// ("4.2 MB", "38 MB"), in the locale's number format.
String formatBytes(int bytes, AppLocalizations l10n, String locale) {
  if (bytes < 1000) return l10n.sizeBytes('$bytes');
  const units = [1e3, 1e6, 1e9];
  final labels = [l10n.sizeKilobytes, l10n.sizeMegabytes, l10n.sizeGigabytes];
  var i = 0;
  while (i < units.length - 1 && bytes >= units[i + 1] * 0.9995) {
    i++;
  }
  final value = bytes / units[i];
  final format = NumberFormat(value < 9.95 ? '0.#' : '0', locale);
  return labels[i](format.format(value));
}

/// Shows a path with the home folder as ~, as Finder's path bar does.
String displayPath(String path, {String? home}) {
  home ??= Platform.environment['HOME'];
  if (home != null && home.isNotEmpty && path.startsWith(home)) {
    return '~${path.substring(home.length)}';
  }
  return path;
}

/// Calm, distinct colors for the usage bar, one per category.
const _categoryColors = {
  StorageCategory.photos: Color(0xFF5B8DEF),
  StorageCategory.videos: Color(0xFF9B87D6),
  StorageCategory.files: Color(0xFF4DB3A6),
  StorageCategory.voiceAndMusic: Color(0xFFE2A651),
  StorageCategory.stickers: Color(0xFFDB8BA8),
  StorageCategory.other: Color(0xFF9C9CA3),
};

String _categoryName(AppLocalizations l10n, StorageCategory category) =>
    switch (category) {
      StorageCategory.photos => l10n.storagePhotos,
      StorageCategory.videos => l10n.storageVideos,
      StorageCategory.files => l10n.storageFiles,
      StorageCategory.voiceAndMusic => l10n.storageVoiceAndMusic,
      StorageCategory.stickers => l10n.storageStickers,
      StorageCategory.other => l10n.storageOther,
    };

/// Data and storage: what the cache holds and clearing it, automatic
/// media download, and where saved files go.
class StoragePage extends ConsumerStatefulWidget {
  const StoragePage({super.key});

  @override
  ConsumerState<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends ConsumerState<StoragePage> {
  /// Categories ticked for clearing; all of them to begin with.
  final _chosen = {...StorageCategory.values};
  var _clearing = false;
  String? _error;

  /// Clears [categories]: the ticked ones that hold something.
  Future<void> _clear(
    StorageUsage usage,
    Set<StorageCategory> categories,
  ) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final size = [for (final c in categories) usage.sizeOf(c)]
        .fold(0, (a, b) => a + b);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.clearCacheTitle(formatBytes(size, l10n, locale)),
      message: l10n.clearCacheMessage,
      confirmLabel: l10n.clear,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null || !mounted) return;
    setState(() {
      _clearing = true;
      _error = null;
    });
    try {
      await ref
          .read(telegramSessionProvider)
          .requireValue
          .storage
          .clear(categories);
      ref.invalidate(storageUsageProvider);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.clearCacheFailed);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _chooseFolder() async {
    final current = ref.read(downloadFolderProvider).value;
    final path = await getDirectoryPath(initialDirectory: current);
    if (path == null) return;
    ref
        .read(preferencesProvider.notifier)
        .update((p) => p.copyWith(downloadFolder: path));
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final p = ref.watch(preferencesProvider);
    final folder = ref.watch(downloadFolderProvider).value;
    void setDownload(AutoDownloadKind kind, AutoDownload value) => ref
        .read(preferencesProvider.notifier)
        .update((p) => p.withAutoDownload(kind, value));
    final kinds = [
      (AutoDownloadKind.photos, l10n.storagePhotos),
      (AutoDownloadKind.videos, l10n.storageVideos),
      (AutoDownloadKind.files, l10n.storageFiles),
    ];

    return SettingsPage(
      children: [
        _usage(context),
        SettingsGroup(
          title: l10n.autoDownload,
          footer: SettingsFooter(l10n.autoDownloadHint),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                settingsInset,
                8,
                settingsInset,
                0,
              ),
              child: Row(
                children: [
                  const Spacer(),
                  for (final label in [
                    l10n.autoDownloadWifi,
                    l10n.autoDownloadOther,
                  ])
                    SizedBox(
                      width: _switchColumn,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: mgTextStyle(
                          c,
                          size: MgType.caption,
                          color: c.fg2,
                          height: 1.25,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (final (kind, label) in kinds)
              SettingsRow(
                key: ValueKey('autoDownload.${kind.name}'),
                title: label,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final other in [false, true])
                      SizedBox(
                        width: _switchColumn,
                        child: Center(
                          child: SettingsSwitch(
                            key: ValueKey(
                              'autoDownload.${kind.name}.'
                              '${other ? 'other' : 'wifi'}',
                            ),
                            label:
                                '$label, ${other ? l10n.autoDownloadOther : l10n.autoDownloadWifi}',
                            value: other
                                ? p.autoDownloadOf(kind).other
                                : p.autoDownloadOf(kind).wifi,
                            onChanged: (v) => setDownload(
                              kind,
                              other
                                  ? p.autoDownloadOf(kind).copyWith(other: v)
                                  : p.autoDownloadOf(kind).copyWith(wifi: v),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        SettingsGroup(
          footer: SettingsFooter(l10n.downloadFolderHint),
          children: [
            SettingsRow(
              key: const ValueKey('downloadFolder'),
              leading: MgIcon(MgIcons.downloadAll, size: 18, color: c.fg2),
              title: l10n.downloadFolder,
              subtitle: folder == null
                  ? l10n.downloadFolderDefault
                  : displayPath(folder),
              trailing: SettingsButton(
                label: l10n.chooseFolder,
                onPressed: _chooseFolder,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Wide enough for "On other networks" under a switch.
  static const _switchColumn = 92.0;

  Widget _usage(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String size(int bytes) => formatBytes(bytes, l10n, locale);
    final state = ref.watch(storageUsageProvider);
    final usage = state.value;
    final Widget body;
    if (usage == null) {
      body = SettingsRow(
        title: state.hasError ? l10n.storageFailed : l10n.storageCalculating,
        trailing: state.hasError
            ? SettingsButton(
                label: l10n.tryAgain,
                onPressed: () => ref.invalidate(storageUsageProvider),
              )
            : const SettingsSpinner(),
      );
      return SettingsGroup(title: l10n.storageUsage, children: [body]);
    }
    final present = [
      for (final category in StorageCategory.values)
        if (usage.sizeOf(category) > 0) category,
    ];
    final chosen = {..._chosen.where(present.contains)};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: l10n.storageUsage,
          footer: SettingsFooter(
            _error ?? l10n.storageHint,
            error: _error != null,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                settingsInset,
                12,
                settingsInset,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    usage.filesSize == 0
                        ? l10n.storageEmpty
                        : l10n.storageUsed(size(usage.filesSize)),
                    style: mgTextStyle(c, weight: FontWeight.w600),
                  ),
                  if (usage.filesSize > 0) ...[
                    const SizedBox(height: 10),
                    _UsageBar(usage: usage, categories: present),
                  ],
                ],
              ),
            ),
            for (final category in present)
              SettingsRow(
                key: ValueKey('storage.${category.name}'),
                leading: _Check(
                  color: _categoryColors[category]!,
                  checked: _chosen.contains(category),
                ),
                title: _categoryName(l10n, category),
                trailing: Text(
                  size(usage.sizeOf(category)),
                  style: mgTextStyle(c, color: c.fg2),
                ),
                onTap: _clearing
                    ? null
                    : () => setState(() {
                        if (!_chosen.remove(category)) _chosen.add(category);
                      }),
              ),
            SettingsRow(
              title: l10n.storageDatabase,
              trailing: Text(
                size(usage.databaseSize),
                style: mgTextStyle(c, color: c.fg2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: _clearing
              ? const Padding(
                  padding: EdgeInsets.all(5),
                  child: SettingsSpinner(),
                )
              : SettingsButton(
                  key: const ValueKey('clearCache'),
                  label: l10n.clearCache,
                  onPressed: chosen.isEmpty
                      ? null
                      : () => _clear(usage, chosen),
                ),
        ),
      ],
    );
  }
}

/// One bar split by category, in the order of the rows below it.
class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.usage, required this.categories});

  final StorageUsage usage;
  final List<StorageCategory> categories;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 8,
        color: c.field,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, category) in categories.indexed) ...[
              if (i > 0) Container(width: 1.5, color: c.windowBackground),
              Expanded(
                // Flex needs whole numbers; kilobytes keep the shares.
                flex: (usage.sizeOf(category) ~/ 1024).clamp(1, 1 << 30),
                child: ColoredBox(color: _categoryColors[category]!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _checkIcon = MgIconData('check', '<path d="M5 12.5l4.5 4.5L19 7"/>');

/// A checkbox tinted with its category's color.
class _Check extends StatelessWidget {
  const _Check({required this.color, required this.checked});

  final Color color;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      checked: checked,
      child: AnimatedContainer(
        duration: settingsMotionOf(context),
        curve: settingsCurve,
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: checked ? color : const Color(0x00000000),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: checked ? color : c.fg2.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: checked
            ? const MgIcon(
                _checkIcon,
                size: 12,
                stroke: 2.6,
                color: Color(0xFFFFFFFF),
              )
            : null,
      ),
    );
  }
}
