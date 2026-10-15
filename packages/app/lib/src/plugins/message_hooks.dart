import 'dart:async';

import 'package:flutter/foundation.dart';
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
/// it is shown as usual. For the chat list's previews and unread counts.
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

/// Gives the timeline below it the filter plugins' answers, so hidden
/// messages leave the list (see [visible]) instead of leaving a gap, and
/// the runs around them join up.
class PluginVerdicts extends ConsumerWidget {
  const PluginVerdicts({super.key, required this.child});

  final Widget child;

  /// [messages] without the ones a filter plugin hides. Asks about the
  /// rest, so their answers are known before they scroll into view.
  static List<ConversationMessage> visible(
    BuildContext context,
    List<ConversationMessage> messages,
  ) {
    final plugins = context
        .dependOnInheritedWidgetOfExactType<_VerdictScope>()
        ?.plugins;
    if (plugins == null || !plugins.filters) return messages;
    return [
      for (final m in messages)
        if (_verdictOf(plugins, m)?.verdict != FilterVerdict.hide) m,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugins = ref.watch(appPluginsProvider).value;
    return _VerdictScope(
      plugins: plugins,
      notifier: plugins?.verdictRevision,
      child: child,
    );
  }
}

class _VerdictScope extends InheritedNotifier<ValueNotifier<int>> {
  const _VerdictScope({
    required this.plugins,
    required super.notifier,
    required super.child,
  });

  final AppPlugins? plugins;

  @override
  bool updateShouldNotify(_VerdictScope old) =>
      old.plugins != plugins || super.updateShouldNotify(old);
}

EventFiltered? _verdictOf(AppPlugins plugins, ConversationMessage message) {
  final m = pluginMessageOf(message);
  return m == null ? null : plugins.verdictNow(m).verdict;
}

/// [child], unless a filter plugin collapses the message into a line with
/// the reason that shows it on a click, or hides it. While the answer is
/// not known yet the message keeps its place without being drawn, so an
/// advertisement never flashes.
class PluginFilteredMessage extends ConsumerWidget {
  const PluginFilteredMessage({
    super.key,
    required this.message,
    required this.child,
  });

  final ConversationMessage message;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugins = ref.watch(appPluginsProvider).value;
    final m = pluginMessageOf(message);
    if (plugins == null || m == null) return child;
    return ValueListenableBuilder(
      valueListenable: plugins.verdictRevision,
      builder: (context, _, _) {
        if (plugins.isRevealed(m)) return child;
        final (:known, :verdict) = plugins.verdictNow(m);
        if (!known) {
          return IgnorePointer(child: Opacity(opacity: 0, child: child));
        }
        return switch (verdict?.verdict) {
          null => child,
          FilterVerdict.hide => const SizedBox.shrink(),
          FilterVerdict.collapse => _Collapsed(
            reason: verdict!.reason,
            onShow: () {
              plugins.reveal(m);
              plugins.verdictRevision.value++;
            },
          ),
        };
      },
    );
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
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              reason ?? l10n.pluginFilteredMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
            ),
          ),
          const SizedBox(width: 8),
          PluginLink(
            label: l10n.pluginShowMessage,
            size: MgType.caption,
            onTap: onShow,
          ),
        ],
      ),
    );
  }
}

/// What plugins show under a message's text, such as a translation, with
/// their buttons working.
class PluginMessageExtras extends ConsumerStatefulWidget {
  const PluginMessageExtras({super.key, required this.message, this.hovered});

  final ConversationMessage message;

  /// Whether the pointer is over the message. An offer that is only
  /// buttons, such as "Translate", shows quietly and only while it is;
  /// what a plugin rendered or answered stays in view.
  final ValueListenable<bool>? hovered;

  @override
  ConsumerState<PluginMessageExtras> createState() =>
      _PluginMessageExtrasState();
}

class _PluginMessageExtrasState extends ConsumerState<PluginMessageExtras> {
  /// What a plugin answered to a click, in place of what it rendered.
  final _answers = <String, List<Map<String, Object?>>>{};
  final _busy = <String>{};
  PluginMessage? _message;

  /// The plugins' revision the answers belong to: a plugin turned off or
  /// a setting changed, such as the language, makes them stale.
  int? _revision;

  @override
  Widget build(BuildContext context) {
    final message = pluginMessageOf(widget.message);
    final plugins = ref.watch(appPluginsProvider).value;
    final revision = plugins?.revision.value;
    if (message != _message || revision != _revision) {
      // An edit, another message in this place, or plugins changed.
      _message = message;
      _revision = revision;
      _answers.clear();
    }
    if (message == null || plugins == null) return const SizedBox.shrink();
    final blocks =
        ref.watch(pluginBlocksProvider(message)).value ??
        plugins.cachedBlocks(message) ??
        const [];
    final shown = [
      for (final b in blocks) (b.pluginId, _answers[b.pluginId] ?? b.ui),
    ].where((b) => b.$2.isNotEmpty);
    if (shown.isEmpty) return const SizedBox.shrink();
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (id, ui) in shown)
          Padding(
            padding: EdgeInsets.only(top: _isOffer(ui) ? 2 : 4),
            child: PluginUiView(
              nodes: ui,
              compact: _isOffer(ui),
              enabled: !_busy.contains(id),
              onAction: (action, payload) =>
                  unawaited(_act(plugins, id, action, payload, message)),
            ),
          ),
      ],
    );
    final hovered = widget.hovered;
    if (hovered == null || !shown.every((b) => _isOffer(b.$2))) return column;
    return ValueListenableBuilder<bool>(
      valueListenable: hovered,
      builder: (context, over, child) => AnimatedOpacity(
        opacity: over ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: IgnorePointer(ignoring: !over, child: child),
      ),
      child: column,
    );
  }

  /// Nothing rendered yet, just a button or two the user may click.
  static bool _isOffer(List<Map<String, Object?>> ui) =>
      ui.isNotEmpty && ui.every((n) => n['type'] == 'button');

  Future<void> _act(
    AppPlugins plugins,
    String pluginId,
    String action,
    Object? payload,
    PluginMessage message,
  ) async {
    setState(() => _busy.add(pluginId));
    List<Map<String, Object?>>? ui;
    try {
      ui = await plugins.action(pluginId, action, payload, message);
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(pluginId);
          if (ui != null && message == _message) _answers[pluginId] = ui;
        });
      }
    }
  }
}
