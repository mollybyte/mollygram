import 'package:flutter/widgets.dart';
import 'package:plugin_host/plugin_host.dart';

/// A plugin as the settings screen sees it.
@immutable
final class PluginEntry {
  const PluginEntry({
    required this.manifest,
    required this.manifestSource,
    this.builtIn = false,
    this.installed = false,
    this.enabled = true,
    this.settings = const {},
    this.updatedAt,
    this.update,
    this.disabledReason,
    this.glyph,
    this.color,
  });

  /// Parses [manifestSource]; throws [ManifestException] when it is invalid.
  factory PluginEntry.parse(
    String manifestSource, {
    bool builtIn = false,
    bool installed = false,
    bool enabled = true,
    Map<String, Object?> settings = const {},
    DateTime? updatedAt,
    String? updateSource,
    String? glyph,
    Color? color,
  }) => PluginEntry(
    manifest: PluginManifest.parse(manifestSource),
    manifestSource: manifestSource.trim(),
    builtIn: builtIn,
    installed: installed || builtIn,
    enabled: enabled,
    settings: settings,
    updatedAt: updatedAt,
    update: updateSource == null
        ? null
        : PluginUpdate(PluginManifest.parse(updateSource), updateSource),
    glyph: glyph,
    color: color,
  );

  final PluginManifest manifest;

  /// The manifest as written, shown under "Manifest".
  final String manifestSource;

  /// Ships with the app: can be turned off but not uninstalled.
  final bool builtIn;
  final bool installed;
  final bool enabled;

  /// Values the user changed; missing keys take manifest defaults.
  final Map<String, Object?> settings;
  final DateTime? updatedAt;

  /// A newer version that asks for more access and waits for consent.
  final PluginUpdate? update;

  /// Why the host turned the plugin off after repeated failures.
  final String? disabledReason;
  final String? glyph;
  final Color? color;

  String get id => manifest.id;
  bool get active => installed && enabled && disabledReason == null;

  Object? setting(String key) => settings.containsKey(key)
      ? settings[key]
      : manifest.settings
            .where((s) => s.key == key)
            .map((s) => s.defaultValue)
            .firstOrNull;

  /// The first letter of the name when the plugin has no glyph.
  String glyphOr(String name) =>
      glyph ?? (name.isEmpty ? '?' : name.characters.first.toUpperCase());

  /// A muted color derived from the id when the plugin has none.
  Color get iconColor {
    if (color != null) return color!;
    const palette = [
      Color(0xFF5E5CE6),
      Color(0xFF0A84FF),
      Color(0xFF30A46C),
      Color(0xFFB07D3A),
      Color(0xFF636366),
      Color(0xFFE5484D),
    ];
    return palette[id.codeUnits.fold(0, (a, c) => a + c) % palette.length];
  }

  PluginEntry copyWith({
    bool? installed,
    bool? enabled,
    Map<String, Object?>? settings,
    PluginManifest? manifest,
    String? manifestSource,
    DateTime? updatedAt,
    PluginUpdate? Function()? update,
    String? Function()? disabledReason,
  }) => PluginEntry(
    manifest: manifest ?? this.manifest,
    manifestSource: manifestSource ?? this.manifestSource,
    builtIn: builtIn,
    installed: installed ?? this.installed,
    enabled: enabled ?? this.enabled,
    settings: settings ?? this.settings,
    updatedAt: updatedAt ?? this.updatedAt,
    update: update == null ? this.update : update(),
    disabledReason: disabledReason == null
        ? this.disabledReason
        : disabledReason(),
    glyph: glyph,
    color: color,
  );
}

@immutable
final class PluginUpdate {
  const PluginUpdate(this.manifest, this.source);

  final PluginManifest manifest;
  final String source;
}

/// What the user is asked to allow.
@immutable
final class ConsentRequest {
  const ConsentRequest._(this.entry, this.permissions, {required this.update});

  final PluginEntry entry;

  /// For an install, everything the plugin asks for; for an update, only
  /// what is new.
  final PermissionSet permissions;

  /// Null for an install.
  final PluginUpdate? update;

  bool get isUpdate => update != null;
}

/// Why a picked plugin was not offered for install.
enum InstallProblem {
  /// The manifest or the bundle is invalid; see [InstallFailure.details].
  invalid,

  /// An older version than the one installed.
  older,

  /// Has the id of one of our own plugins.
  builtIn,
}

@immutable
final class InstallFailure {
  const InstallFailure(this.problem, {this.details = const []});

  final InstallProblem problem;

  /// The manifest errors, as the host wrote them.
  final List<String> details;
}

/// Connects the screen to the running plugins. The app implements it; the
/// screen works without it against its own state (mock data, tests).
abstract interface class PluginsDelegate {
  Future<void> install(PluginEntry entry);
  Future<void> uninstall(PluginEntry entry);
  Future<void> setEnabled(PluginEntry entry, bool enabled);
  Future<void> setSetting(PluginEntry entry, String key, Object? value);
  Future<void> applyUpdate(PluginEntry entry, PluginUpdate update);

  /// Opens a file picker and returns the chosen plugin, or null. Throws
  /// [ManifestException] for a bundle that is not a valid plugin.
  Future<PluginEntry?> pickFile();
}

/// State of the plugins screen.
final class PluginsController extends ChangeNotifier {
  PluginsController(
    List<PluginEntry> entries, {
    String? selected,
    this.delegate,
  }) : _entries = [...entries],
       _selected = selected ?? entries.firstOrNull?.id;

  final PluginsDelegate? delegate;
  final List<PluginEntry> _entries;
  String? _selected;
  String _query = '';
  bool _manifestOpen = false;
  ConsentRequest? _consent;
  InstallFailure? _installFailure;

  /// Why the last picked file was not installed, until dismissed.
  InstallFailure? get installFailure => _installFailure;

  void dismissInstallFailure() {
    _installFailure = null;
    notifyListeners();
  }

  List<PluginEntry> get entries => List.unmodifiable(_entries);
  String get query => _query;
  bool get manifestOpen => _manifestOpen;
  ConsentRequest? get consent => _consent;

  PluginEntry? get selected =>
      _entries.where((e) => e.id == _selected).firstOrNull;

  PluginEntry? entry(String id) =>
      _entries.where((e) => e.id == id).firstOrNull;

  /// Entries matching the search, as installed and available groups.
  ///
  /// [nameOf] gives the shown, possibly translated, name.
  ({List<PluginEntry> installed, List<PluginEntry> available}) groups(
    String Function(PluginEntry) nameOf,
  ) {
    final q = _query.trim().toLowerCase();
    bool match(PluginEntry e) =>
        q.isEmpty ||
        nameOf(e).toLowerCase().contains(q) ||
        e.manifest.name.toLowerCase().contains(q) ||
        (e.manifest.author ?? '').toLowerCase().contains(q);
    final shown = _entries.where(match);
    return (
      installed: shown.where((e) => e.installed).toList(),
      available: shown.where((e) => !e.installed).toList(),
    );
  }

  set query(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void select(String id) {
    if (id == _selected) return;
    _selected = id;
    _manifestOpen = false;
    notifyListeners();
  }

  void toggleManifest() {
    _manifestOpen = !_manifestOpen;
    notifyListeners();
  }

  /// Asks for consent before installing; a plugin that asks for nothing is
  /// installed right away.
  void requestInstall(String id) {
    final e = entry(id);
    if (e == null || e.installed) return;
    if (_isEmpty(e.manifest.permissions)) {
      _install(e);
      return;
    }
    _consent = ConsentRequest._(e, e.manifest.permissions, update: null);
    notifyListeners();
  }

  /// Asks for consent to the access a pending update adds.
  void requestUpdate(String id) {
    final e = entry(id);
    final u = e?.update;
    if (e == null || u == null) return;
    _consent = ConsentRequest._(
      e,
      escalation(u.manifest.permissions, e.manifest.permissions),
      update: u,
    );
    notifyListeners();
  }

  void cancelConsent() {
    _consent = null;
    notifyListeners();
  }

  Future<void> allowConsent() async {
    final c = _consent;
    if (c == null) return;
    _consent = null;
    final e = entry(c.entry.id)!;
    final u = c.update;
    u == null ? await _install(e) : await _applyUpdate(e, u);
  }

  Future<void> _applyUpdate(PluginEntry e, PluginUpdate u) async {
    _replace(
      e.copyWith(
        manifest: u.manifest,
        manifestSource: u.source.trim(),
        updatedAt: DateTime.now(),
        update: () => null,
      ),
    );
    await delegate?.applyUpdate(e, u);
  }

  Future<void> _install(PluginEntry e) async {
    _replace(e.copyWith(installed: true, enabled: true));
    await delegate?.install(e);
  }

  Future<void> uninstall(String id) async {
    final e = entry(id);
    if (e == null || e.builtIn || !e.installed) return;
    _replace(
      e.copyWith(
        installed: false,
        settings: const {},
        disabledReason: () => null,
      ),
    );
    await delegate?.uninstall(e);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final e = entry(id);
    if (e == null || !e.installed) return;
    // Turning a plugin back on clears the failure that disabled it.
    _replace(e.copyWith(enabled: enabled, disabledReason: () => null));
    await delegate?.setEnabled(e, enabled);
  }

  Future<void> setSetting(String id, String key, Object? value) async {
    final e = entry(id);
    if (e == null || !e.manifest.settings.any((s) => s.key == key)) return;
    _replace(e.copyWith(settings: {...e.settings, key: value}));
    await delegate?.setSetting(e, key, value);
  }

  /// Reports that the host turned a plugin off, see `PluginWorker`.
  void markDisabled(String id, String reason) {
    final e = entry(id);
    if (e == null) return;
    _replace(e.copyWith(disabledReason: () => reason));
  }

  Future<void> installFromFile() async {
    final d = delegate;
    if (d == null) return;
    final PluginEntry picked;
    try {
      final file = await d.pickFile();
      if (file == null) return;
      picked = file;
    } on ManifestException catch (e) {
      _fail(InstallFailure(InstallProblem.invalid, details: e.errors));
      return;
    }
    final i = _entries.indexWhere((e) => e.id == picked.id);
    final current = i < 0 ? null : _entries[i];
    if (current != null && current.builtIn) {
      _fail(const InstallFailure(InstallProblem.builtIn));
      return;
    }
    if (current == null) {
      _entries.add(picked.copyWith(installed: false));
    } else if (!current.installed) {
      _entries[i] = picked.copyWith(installed: false);
    } else {
      if (compareVersions(picked.manifest.version, current.manifest.version) <
          0) {
        _fail(const InstallFailure(InstallProblem.older));
        return;
      }
      // Installing a newer version of an installed plugin is an update:
      // the old version keeps running until the user allows what it adds.
      final added = escalation(
        picked.manifest.permissions,
        current.manifest.permissions,
      );
      final u = PluginUpdate(picked.manifest, picked.manifestSource);
      _selected = picked.id;
      if (_isEmpty(added)) {
        await _applyUpdate(current, u);
      } else {
        _entries[i] = current.copyWith(update: () => u);
        requestUpdate(picked.id);
      }
      return;
    }
    _selected = picked.id;
    requestInstall(picked.id);
    notifyListeners();
  }

  void _fail(InstallFailure failure) {
    _installFailure = failure;
    notifyListeners();
  }

  void _replace(PluginEntry e) {
    final i = _entries.indexWhere((x) => x.id == e.id);
    _entries[i] = e;
    notifyListeners();
  }

  static bool _isEmpty(PermissionSet p) =>
      p.messagesRead == MessagesScope.none &&
      !p.composerWrite &&
      p.net.isEmpty &&
      p.storageBytes == 0 &&
      !p.notificationsManage &&
      p.mediaRead.isEmpty;
}

/// The part of [next] that [previous] did not allow, as a set of its own,
/// matching [PermissionSet.escalationsFrom].
PermissionSet escalation(PermissionSet next, PermissionSet previous) =>
    PermissionSet(
      messagesRead: next.messagesRead.index > previous.messagesRead.index
          ? next.messagesRead
          : MessagesScope.none,
      composerWrite: next.composerWrite && !previous.composerWrite,
      net: next.net.difference(previous.net),
      storageBytes: next.storageBytes > previous.storageBytes
          ? next.storageBytes
          : 0,
      notificationsManage:
          next.notificationsManage && !previous.notificationsManage,
      mediaRead: next.mediaRead.difference(previous.mediaRead),
    );
