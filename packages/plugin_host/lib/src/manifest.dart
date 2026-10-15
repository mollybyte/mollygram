import 'package:yaml/yaml.dart';

import 'permissions.dart';

/// The API version this host implements.
///
/// A plugin specifies a range in the `sdk` field; compatibility is checked
/// against the major version.
const hostSdkVersion = (major: 1, minor: 1);

final class ManifestException implements Exception {
  ManifestException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'Invalid manifest:\n- ${errors.join('\n- ')}';
}

final class PluginCommand {
  const PluginCommand({required this.name, required this.title, this.shortcut});

  /// The command name, for example `/summary`.
  ///
  /// The ⌘K palette shows the commands of all plugins.
  final String name;
  final String title;
  final String? shortcut;
}

enum SettingType { toggle, select, text }

final class PluginSetting {
  const PluginSetting({
    required this.key,
    required this.type,
    required this.label,
    this.defaultValue,
    this.options = const [],
  });

  final String key;
  final SettingType type;
  final String label;
  final Object? defaultValue;

  /// For `select`: value and label pairs.
  final List<({String value, String label})> options;
}

/// A parsed `manifest.yaml`.
///
/// Everything a plugin can do is visible here: permissions, hooks, commands
/// and settings. The host never grants more than is declared.
final class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.sdk,
    required this.main,
    required this.permissions,
    this.author,
    this.description,
    this.hooks = const [],
    this.commands = const [],
    this.settings = const [],
  });

  final String id;
  final String name;
  final String version;
  final String sdk;
  final String main;
  final String? author;
  final String? description;
  final PermissionSet permissions;
  final List<String> hooks;
  final List<PluginCommand> commands;
  final List<PluginSetting> settings;

  static final _idPattern = RegExp(r'^[a-z][a-z0-9-]*(\.[a-z0-9-]+){2,}$');
  static final _semver = RegExp(r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$');
  static final _sdkRange = RegExp(r'^\^(\d+)\.(\d+)(?:\.\d+)?$');
  static final _command = RegExp(r'^/[a-z][a-z0-9_]{0,31}$');
  static final _main = RegExp(r'^[A-Za-z0-9_\-][A-Za-z0-9_.\-/]*\.js$');

  static const _knownKeys = {
    'id',
    'name',
    'version',
    'author',
    'description',
    'runtime',
    'sdk',
    'main',
    'permissions',
    'hooks',
    'commands',
    'settings',
  };

  factory PluginManifest.parse(String source) {
    final Object? doc;
    try {
      doc = loadYaml(source);
    } on YamlException catch (e) {
      throw ManifestException(['YAML: ${e.message}']);
    }
    if (doc is! YamlMap) throw ManifestException(['expected an object']);
    final YamlMap map = doc;
    final errors = <String>[];

    for (final key in map.keys) {
      if (!_knownKeys.contains(key)) errors.add('unknown field "$key"');
    }

    String? str(String key, {bool required = true}) {
      final v = map[key];
      if (v == null) {
        if (required) errors.add('missing field "$key"');
        return null;
      }
      if (v is! String || v.trim().isEmpty) {
        errors.add('"$key" must be a non-empty string');
        return null;
      }
      return v.trim();
    }

    final id = str('id');
    if (id != null && !_idPattern.hasMatch(id)) {
      errors.add(
        'id "$id" must be in reverse domain notation, '
        'for example dev.example.plugin',
      );
    }
    final name = str('name');
    if (name != null && name.length > 40) {
      errors.add('name is longer than 40 characters');
    }
    final version = str('version');
    if (version != null && !_semver.hasMatch(version)) {
      errors.add('version "$version" is not semver');
    }
    final runtime = str('runtime');
    if (runtime != null && runtime != 'js') {
      errors.add(
        'runtime "$runtime" is not supported: plugins are JS only, '
        'native code is never loaded',
      );
    }
    final sdk = str('sdk');
    int? sdkMinor;
    if (sdk != null) {
      final m = _sdkRange.firstMatch(sdk);
      if (m == null) {
        errors.add('sdk must be a range like ^1.0');
      } else {
        final major = int.parse(m[1]!), minor = sdkMinor = int.parse(m[2]!);
        if (major != hostSdkVersion.major || minor > hostSdkVersion.minor) {
          errors.add(
            'plugin requires SDK $sdk, host implements '
            '${hostSdkVersion.major}.${hostSdkVersion.minor}',
          );
        }
      }
    }
    final main = str('main', required: false) ?? 'index.js';
    if (!_main.hasMatch(main) || main.split('/').contains('..')) {
      errors.add('main "$main" must be a relative path to a .js file');
    }

    PermissionSet permissions = PermissionSet.none;
    try {
      permissions = PermissionSet.parse(map['permissions']);
    } on FormatException catch (e) {
      errors.add(e.message);
    }

    final hooks = <String>[];
    final rawHooks = map['hooks'];
    if (rawHooks != null) {
      if (rawHooks is! YamlList) {
        errors.add('hooks must be a list');
      } else {
        for (final h in rawHooks) {
          final event = h is String ? PluginEvent.byName[h] : null;
          if (event == null) {
            errors.add('unknown hook "$h"');
            continue;
          }
          if (sdkMinor != null && event.sinceMinor > sdkMinor) {
            errors.add('hook "$h" requires sdk ^1.${event.sinceMinor}');
          }
          final missing = event.requires(permissions);
          if (missing != null) {
            errors.add('hook "$h" requires permission $missing');
          }
          hooks.add(h as String);
        }
      }
    }

    final commands = <PluginCommand>[];
    final rawCommands = map['commands'];
    if (rawCommands != null) {
      if (rawCommands is! YamlList) {
        errors.add('commands must be a list');
      } else {
        for (final c in rawCommands) {
          if (c is! YamlMap || c['name'] is! String || c['title'] is! String) {
            errors.add('a command must have name and title');
            continue;
          }
          final cname = c['name'] as String;
          if (!_command.hasMatch(cname)) {
            errors.add(
              'command "$cname" must start with / and consist of '
              'lowercase Latin letters',
            );
          }
          commands.add(
            PluginCommand(
              name: cname,
              title: c['title'] as String,
              shortcut: c['shortcut'] as String?,
            ),
          );
        }
      }
    }

    final settings = <PluginSetting>[];
    final rawSettings = map['settings'];
    if (rawSettings != null) {
      if (rawSettings is! YamlList) {
        errors.add('settings must be a list');
      } else {
        for (final s in rawSettings) {
          final parsed = _parseSetting(s, errors);
          if (parsed != null) settings.add(parsed);
        }
      }
    }

    if (errors.isNotEmpty) throw ManifestException(errors);
    return PluginManifest(
      id: id!,
      name: name!,
      version: version!,
      sdk: sdk!,
      main: main,
      author: str('author', required: false),
      description: str('description', required: false),
      permissions: permissions,
      hooks: List.unmodifiable(hooks),
      commands: List.unmodifiable(commands),
      settings: List.unmodifiable(settings),
    );
  }

  static PluginSetting? _parseSetting(Object? s, List<String> errors) {
    if (s is! YamlMap || s['key'] is! String || s['label'] is! String) {
      errors.add('a setting must have key and label');
      return null;
    }
    final key = s['key'] as String;
    final type = SettingType.values.asNameMap()[s['type']];
    if (type == null) {
      errors.add('setting "$key": type must be toggle, select or text');
      return null;
    }
    final def = s['default'];
    final options = <({String value, String label})>[];
    if (type == SettingType.select) {
      final raw = s['options'];
      if (raw is! YamlList || raw.isEmpty) {
        errors.add('setting "$key": select requires options');
        return null;
      }
      for (final o in raw) {
        if (o is YamlMap && o['value'] is String && o['label'] is String) {
          options.add((
            value: o['value'] as String,
            label: o['label'] as String,
          ));
        } else {
          errors.add('setting "$key": an option must have value and label');
        }
      }
    }
    final defOk = switch (type) {
      SettingType.toggle => def == null || def is bool,
      SettingType.text => def == null || def is String,
      SettingType.select => def == null || options.any((o) => o.value == def),
    };
    if (!defOk) errors.add('setting "$key": default does not match the type');
    return PluginSetting(
      key: key,
      type: type,
      label: s['label'] as String,
      defaultValue: def ?? (type == SettingType.toggle ? false : null),
      options: List.unmodifiable(options),
    );
  }
}

/// Orders two semver versions: negative when [a] is older than [b].
///
/// Build metadata is ignored; a pre-release sorts before its release, and
/// pre-releases compare as text.
int compareVersions(String a, String b) {
  (List<int>, String?) parse(String v) {
    final core = v.split('+').first;
    final dash = core.indexOf('-');
    final numbers = dash < 0 ? core : core.substring(0, dash);
    return (
      [for (final p in numbers.split('.')) int.tryParse(p) ?? 0],
      dash < 0 ? null : core.substring(dash + 1),
    );
  }

  final (x, xPre) = parse(a);
  final (y, yPre) = parse(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  if (xPre == yPre) return 0;
  if (xPre == null) return 1;
  if (yPre == null) return -1;
  return xPre.compareTo(yPre);
}
