import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

import '../commands/command_registry.dart';
import '../home/workspace.dart';
import 'app_plugins.dart';

/// Lists the commands of the plugins that are on in the ⌘K palette, under
/// the owner `plugins`, while something watches it. A command runs in the
/// chat in front, if any (`messages.read: on_command`).
final pluginCommandsProvider = Provider.autoDispose<void>((ref) {
  final registry = ref.watch(commandRegistryProvider);
  final plugins = ref.watch(appPluginsProvider).value;
  if (plugins == null) return;
  final workspace = ref.watch(workspaceControllerProvider);
  Iterable<PaletteCommand> source() => [
    for (final (:plugin, :command) in plugins.commands)
      PaletteCommand(
        id: 'plugin.${plugin.id}.${command.name.substring(1)}',
        title: command.title,
        subtitle: plugin.manifest.name,
        keywords: [command.name, plugin.manifest.name],
        run: () => unawaited(
          plugins.runCommand(
            plugin.id,
            command.name,
            chatId: workspace.value.focusedChat,
          ),
        ),
      ),
  ];
  registry.register('plugins', source);
  ref.onDispose(() => registry.unregister('plugins', source));
});
