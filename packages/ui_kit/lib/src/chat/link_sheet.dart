import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../glass/glass.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// Localized labels of the composer's formatting menu and link sheet.
@immutable
class FormatLabels {
  const FormatLabels({
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strikethrough,
    required this.monospace,
    required this.spoiler,
    required this.quote,
    required this.link,
    required this.plain,
    required this.linkTitle,
    required this.linkHint,
    required this.apply,
    required this.cancel,
  });

  final String bold;
  final String italic;
  final String underline;
  final String strikethrough;
  final String monospace;
  final String spoiler;
  final String quote;
  final String link;

  /// Removes all formatting from the selection.
  final String plain;

  /// The link sheet: its title, the URL field's placeholder, its buttons.
  final String linkTitle;
  final String linkHint;
  final String apply;
  final String cancel;
}

/// Whether [text] looks like a web address, to prefill the link sheet
/// from the clipboard.
bool looksLikeUrl(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return false;
  final uri = Uri.tryParse(
    trimmed.contains('://') ? trimmed : 'https://$trimmed',
  );
  if (uri == null || uri.host.isEmpty) return false;
  return trimmed.contains('://') || uri.host.contains('.');
}

/// Asks for the address of a link. Completes with the address, an empty
/// string when the user cleared it (to remove the link), or null when
/// cancelled.
Future<String?> showLinkSheet(
  BuildContext context, {
  required FormatLabels labels,
  String initial = '',
}) => showGeneralDialog<String>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: const Color(0x00000000),
  // The same short, eased entrance as the other sheets.
  transitionDuration: const Duration(milliseconds: 160),
  transitionBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(curved),
        child: child,
      ),
    );
  },
  pageBuilder: (context, _, _) => Center(
    child: _LinkSheet(labels: labels, initial: initial),
  ),
);

class _LinkSheet extends StatefulWidget {
  const _LinkSheet({required this.labels, required this.initial});

  final FormatLabels labels;
  final String initial;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final _url = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _apply() {
    var url = _url.text.trim();
    if (url.isNotEmpty && !url.contains('://') && !url.startsWith('mailto:')) {
      url = 'https://$url';
    }
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l = widget.labels;
    final style = mgTextStyle(c);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: 320,
          child: Glass(
            radius: 14,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.linkTitle,
                  style: mgTextStyle(c, weight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: c.field,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: TextField(
                    controller: _url,
                    autofocus: true,
                    style: style,
                    cursorHeight: 15,
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) => _apply(),
                    decoration: InputDecoration.collapsed(
                      hintText: l.linkHint,
                      hintStyle: style.copyWith(color: c.fg2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _SheetButton(
                      label: l.cancel,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    _SheetButton(label: l.apply, filled: true, onTap: _apply),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? c.accent : c.field,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              label,
              style: mgTextStyle(
                c,
                weight: filled ? FontWeight.w600 : null,
                color: filled ? c.onAccent : c.fg,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
