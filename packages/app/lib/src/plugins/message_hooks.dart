import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:plugin_host/plugin_host.dart';

import '../../l10n/app_localizations.dart';
import '../chat/message_tile.dart';
import 'app_plugins.dart';
import 'plugin_ui.dart';

/// [message] as plugins see it, or null when plugins have nothing to look
/// at: chat events and messages without text.
PluginMessage? pluginMessageOf(ConversationMessage message) {
  if (message.isService || message.text.isEmpty) return null;
  return (
    chatId: message.chatId,
    id: message.id,
    senderId: message.sender.id,
    date: message.date,
    text: message.text,
    outgoing: message.isOutgoing,
  );
}

/// Whether `message.filter` plugins collapse or hide a message; null while
/// it is shown as usual. The chat list can use it for previews too.
final messageVisibilityProvider = FutureProvider.autoDispose
    .family<EventFiltered?, PluginMessage>((ref, message) async {
      final plugins = await ref.watch(appPluginsProvider.future);
      _followChanges(ref, plugins);
      return plugins.filterMessage(message);
    });

/// What `message.render.text` plugins show under a message.
final pluginBlocksProvider = FutureProvider.autoDispose
    .family<List<PluginBlock>, PluginMessage>((ref, message) async {
      final plugins = await ref.watch(appPluginsProvider.future);
      _followChanges(ref, plugins);
      return plugins.renderText(message);
    });

void _followChanges(Ref ref, AppPlugins plugins) {
  void changed() => ref.invalidateSelf();
  plugins.revision.addListener(changed);
  ref.onDispose(() => plugins.revision.removeListener(changed));
}

/// [child], unless a filter plugin hides the message, or collapses it into
/// a line with the reason that shows it on a click.
class PluginFilteredMessage extends ConsumerStatefulWidget {
  const PluginFilteredMessage({
    super.key,
    required this.message,
    required this.child,
  });

  final ConversationMessage message;
  final Widget child;

  @override
  ConsumerState<PluginFilteredMessage> createState() =>
      _PluginFilteredMessageState();
}

class _PluginFilteredMessageState extends ConsumerState<PluginFilteredMessage> {
  var _shown = false;

  @override
  Widget build(BuildContext context) {
    final message = pluginMessageOf(widget.message);
    if (message == null || _shown) return widget.child;
    final verdict = ref.watch(messageVisibilityProvider(message)).value;
    return switch (verdict?.verdict) {
      null => widget.child,
      FilterVerdict.hide => const SizedBox.shrink(),
      FilterVerdict.collapse => _Collapsed(
        reason: verdict!.reason,
        onShow: () => setState(() => _shown = true),
      ),
    };
  }
}

class _Collapsed extends StatelessWidget {
  const _Collapsed({required this.reason, required this.onShow});

  final String? reason;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: MessageTile.contentIndent,
        top: 4,
        bottom: 2,
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              reason ?? l10n.pluginFilteredMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mgTextStyle(c, color: c.fg2),
            ),
          ),
          const SizedBox(width: 8),
          PluginLink(label: l10n.pluginShowMessage, onTap: onShow),
        ],
      ),
    );
  }
}

/// What plugins show under a message's text, such as a translation, with
/// their buttons working.
class PluginMessageExtras extends ConsumerStatefulWidget {
  const PluginMessageExtras({super.key, required this.message});

  final ConversationMessage message;

  @override
  ConsumerState<PluginMessageExtras> createState() =>
      _PluginMessageExtrasState();
}

class _PluginMessageExtrasState extends ConsumerState<PluginMessageExtras> {
  /// What a plugin answered to a click, in place of what it rendered.
  final _answers = <String, List<Map<String, Object?>>>{};
  final _busy = <String>{};
  PluginMessage? _message;

  @override
  Widget build(BuildContext context) {
    final message = pluginMessageOf(widget.message);
    if (message != _message) {
      // An edit or another message in this place: earlier answers go.
      _message = message;
      _answers.clear();
    }
    if (message == null) return const SizedBox.shrink();
    final blocks = ref.watch(pluginBlocksProvider(message)).value ?? const [];
    final shown = [
      for (final b in blocks) (b.pluginId, _answers[b.pluginId] ?? b.ui),
    ].where((b) => b.$2.isNotEmpty);
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (id, ui) in shown)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: PluginUiView(
              nodes: ui,
              enabled: !_busy.contains(id),
              onAction: (action, payload) =>
                  unawaited(_act(id, action, payload, message)),
            ),
          ),
      ],
    );
  }

  Future<void> _act(
    String pluginId,
    String action,
    Object? payload,
    PluginMessage message,
  ) async {
    setState(() => _busy.add(pluginId));
    final plugins = await ref.read(appPluginsProvider.future);
    final ui = await plugins.action(pluginId, action, payload, message);
    if (!mounted) return;
    setState(() {
      _busy.remove(pluginId);
      if (ui != null && message == _message) _answers[pluginId] = ui;
    });
  }
}
