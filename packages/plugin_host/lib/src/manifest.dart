import 'package:yaml/yaml.dart';

import 'permissions.dart';

/// Версия API, которую реализует этот хост. Плагин указывает диапазон в
/// поле `sdk`, совместимость проверяется по старшей цифре.
const hostSdkVersion = (major: 1, minor: 0);

final class ManifestException implements Exception {
  ManifestException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'Некорректный манифест:\n- ${errors.join('\n- ')}';
}

final class PluginCommand {
  const PluginCommand({required this.name, required this.title, this.shortcut});

  /// Например `/summary`. Палитра ⌘K показывает команды всех плагинов.
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

  /// Для `select`: пары значение — подпись.
  final List<({String value, String label})> options;
}

/// Разобранный `manifest.yaml`. Всё, что плагин может делать, видно здесь:
/// права, хуки, команды и параметры. Хост не даёт больше, чем объявлено.
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
    if (doc is! YamlMap) throw ManifestException(['ожидался объект']);
    final YamlMap map = doc;
    final errors = <String>[];

    for (final key in map.keys) {
      if (!_knownKeys.contains(key)) errors.add('неизвестное поле "$key"');
    }

    String? str(String key, {bool required = true}) {
      final v = map[key];
      if (v == null) {
        if (required) errors.add('нет поля "$key"');
        return null;
      }
      if (v is! String || v.trim().isEmpty) {
        errors.add('"$key" должно быть непустой строкой');
        return null;
      }
      return v.trim();
    }

    final id = str('id');
    if (id != null && !_idPattern.hasMatch(id)) {
      errors.add(
        'id "$id" должен быть в обратной доменной записи, '
        'например dev.example.plugin',
      );
    }
    final name = str('name');
    if (name != null && name.length > 40) {
      errors.add('name длиннее 40 символов');
    }
    final version = str('version');
    if (version != null && !_semver.hasMatch(version)) {
      errors.add('version "$version" не semver');
    }
    final runtime = str('runtime');
    if (runtime != null && runtime != 'js') {
      errors.add(
        'runtime "$runtime" не поддерживается: плагины только на JS, '
        'нативный код не загружается',
      );
    }
    final sdk = str('sdk');
    if (sdk != null) {
      final m = _sdkRange.firstMatch(sdk);
      if (m == null) {
        errors.add('sdk должен быть диапазоном вида ^1.0');
      } else {
        final major = int.parse(m[1]!), minor = int.parse(m[2]!);
        if (major != hostSdkVersion.major || minor > hostSdkVersion.minor) {
          errors.add(
            'плагин требует SDK $sdk, хост реализует '
            '${hostSdkVersion.major}.${hostSdkVersion.minor}',
          );
        }
      }
    }
    final main = str('main', required: false) ?? 'index.js';
    if (!_main.hasMatch(main) || main.split('/').contains('..')) {
      errors.add('main "$main" должен быть относительным путём к .js');
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
        errors.add('hooks должен быть списком');
      } else {
        for (final h in rawHooks) {
          final event = h is String ? PluginEvent.byName[h] : null;
          if (event == null) {
            errors.add('неизвестный хук "$h"');
            continue;
          }
          final missing = event.requires(permissions);
          if (missing != null) {
            errors.add('хук "$h" требует права $missing');
          }
          hooks.add(h as String);
        }
      }
    }

    final commands = <PluginCommand>[];
    final rawCommands = map['commands'];
    if (rawCommands != null) {
      if (rawCommands is! YamlList) {
        errors.add('commands должен быть списком');
      } else {
        for (final c in rawCommands) {
          if (c is! YamlMap || c['name'] is! String || c['title'] is! String) {
            errors.add('команда должна иметь name и title');
            continue;
          }
          final cname = c['name'] as String;
          if (!_command.hasMatch(cname)) {
            errors.add(
              'команда "$cname" должна начинаться с / и состоять из '
              'латиницы в нижнем регистре',
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
        errors.add('settings должен быть списком');
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
      errors.add('параметр должен иметь key и label');
      return null;
    }
    final key = s['key'] as String;
    final type = SettingType.values.asNameMap()[s['type']];
    if (type == null) {
      errors.add('параметр "$key": type должен быть toggle, select или text');
      return null;
    }
    final def = s['default'];
    final options = <({String value, String label})>[];
    if (type == SettingType.select) {
      final raw = s['options'];
      if (raw is! YamlList || raw.isEmpty) {
        errors.add('параметр "$key": у select нужны options');
        return null;
      }
      for (final o in raw) {
        if (o is YamlMap && o['value'] is String && o['label'] is String) {
          options.add((
            value: o['value'] as String,
            label: o['label'] as String,
          ));
        } else {
          errors.add('параметр "$key": вариант должен иметь value и label');
        }
      }
    }
    final defOk = switch (type) {
      SettingType.toggle => def == null || def is bool,
      SettingType.text => def == null || def is String,
      SettingType.select => def == null || options.any((o) => o.value == def),
    };
    if (!defOk) errors.add('параметр "$key": default не подходит к типу');
    return PluginSetting(
      key: key,
      type: type,
      label: s['label'] as String,
      defaultValue: def ?? (type == SettingType.toggle ? false : null),
      options: List.unmodifiable(options),
    );
  }
}
