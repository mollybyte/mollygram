import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/widgets.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'code_highlight.dart';

/// Draws the declarative UI a plugin returned (already validated by the
/// host) with the app's own widgets: a plugin picks what to show, never how
/// it looks. Spec: docs/plugins.md, "Declarative UI".
class PluginUiView extends StatelessWidget {
  const PluginUiView({
    super.key,
    required this.nodes,
    required this.onAction,
    this.enabled = true,
    this.compact = false,
  });

  final List<Map<String, Object?>> nodes;

  /// Buttons at the meta size, for a quiet offer under a message.
  final bool compact;

  /// A click on a button or toggle: its action and payload.
  final void Function(String action, Object? payload) onAction;

  /// False while the plugin is still answering the last click.
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (final n in nodes) _node(context, n)],
  );

  Widget _node(BuildContext context, Map<String, Object?> n) {
    final c = MgColors.of(context);
    List<Widget> children() => [
      for (final child in n['children']! as List)
        _node(context, (child as Map).cast()),
    ];
    switch (n['type']) {
      case 'text':
        return Text(n['text']! as String, style: _style(c, n['style']));
      case 'button':
        return PluginLink(
          label: n['label']! as String,
          size: compact ? MgType.meta : MgType.body,
          onTap: enabled
              ? () => onAction(n['action']! as String, n['payload'])
              : null,
        );
      case 'toggle':
        final value = n['value'] == true;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MgSwitch(
              value: value,
              onChanged: enabled
                  ? (v) => onAction(n['action']! as String, {'value': v})
                  : null,
            ),
            const SizedBox(width: 8),
            Text(n['label']! as String, style: mgTextStyle(c)),
          ],
        );
      case 'progress':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 6),
            const SizedBox(width: 6),
            Text(n['label']! as String, style: mgTextStyle(c, color: c.fg2)),
          ],
        );
      case 'row':
        return Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children(),
        );
      case 'column':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children(),
        );
      case 'code':
        return Text.rich(
          TextSpan(
            style: _style(c, 'mono'),
            children: [
              for (final s in n['spans']! as List)
                TextSpan(
                  text: (s as Map)['text'] as String,
                  style: TextStyle(
                    color: codeTokenColor(s['token'] as String, c),
                  ),
                ),
            ],
          ),
        );
    }
    return const SizedBox.shrink();
  }

  static TextStyle _style(MgColors c, Object? style) => switch (style) {
    'secondary' => mgTextStyle(c, color: c.fg2),
    'mono' => mgTextStyle(
      c,
    ).copyWith(fontFamily: monoFamily, fontFamilyFallback: monoFallback),
    _ => mgTextStyle(c),
  };
}

/// An inline action in the accent color, as Telegram's "Translate" under a
/// message.
class PluginLink extends StatefulWidget {
  const PluginLink({
    super.key,
    required this.label,
    this.onTap,
    this.size = MgType.body,
  });

  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  State<PluginLink> createState() => _PluginLinkState();
}

class _PluginLinkState extends State<PluginLink> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Text(
            widget.label,
            style:
                mgTextStyle(
                  c,
                  size: widget.size,
                  color: enabled ? c.accent : c.fg2,
                ).copyWith(
                  decoration: _hover && enabled
                      ? TextDecoration.underline
                      : null,
                  decorationColor: c.accent,
                ),
          ),
        ),
      ),
    );
  }
}
