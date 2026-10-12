import 'dart:async';

import 'package:plugin_host/plugin_host.dart';

/// Fake services: in-memory storage and speech recognition that returns
/// predefined text.
final class FakeServices implements PluginServices {
  final storage = <String, Object?>{};
  final calls = <String>[];
  String transcript = 'hello, this is a voice message';
  Duration delay = Duration.zero;
  Object? failWith;

  @override
  Future<Object?> call(
    String pluginId,
    String method,
    Map<String, Object?> args,
  ) async {
    calls.add(method);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failWith != null) throw failWith!;
    switch (method) {
      case 'storage.get':
        return storage['$pluginId/${args['key']}'];
      case 'storage.set':
        storage['$pluginId/${args['key']}'] = args['value'];
        return null;
      case 'storage.delete':
        storage.remove('$pluginId/${args['key']}');
        return null;
      case 'media.transcribe':
        return {'text': transcript, 'language': args['language'] ?? 'ru'};
      case 'messages.get':
        return {'chatId': args['chatId'], 'id': args['messageId'], 'text': 'x'};
      case 'net.fetch':
        return {'status': 200, 'headers': <String, String>{}, 'text': 'ok'};
      default:
        return null;
    }
  }
}

PluginManifest manifest({
  String permissions = '',
  String hooks = '',
  String extra = '',
}) => PluginManifest.parse('''
id: dev.test.plugin
name: Test
version: 1.0.0
runtime: js
sdk: ^1.0
${permissions.isEmpty ? '' : 'permissions:\n$permissions'}
${hooks.isEmpty ? '' : 'hooks:\n$hooks'}
$extra
''');
