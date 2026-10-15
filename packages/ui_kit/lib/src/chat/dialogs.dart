import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../glass/glass.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'message_menu.dart';

Future<T?> _showAlert<T>(BuildContext context, Widget child) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0x00000000),
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => Center(
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );

/// A macOS-style alert that asks to pick one of [options], such as the
/// reason of a report. Completes with the index picked, or null when
/// cancelled.
Future<int?> showMgChoice(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String cancelLabel,
}) => _showAlert<int>(
  context,
  _Choice(title: title, options: options, cancelLabel: cancelLabel),
);

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.options,
    required this.cancelLabel,
  });

  final String title;
  final List<String> options;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: 300,
          child: Glass(
            radius: 14,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: mgTextStyle(c, weight: FontWeight.w600)),
                const SizedBox(height: 10),
                for (var i = 0; i < options.length; i++)
                  _ChoiceRow(
                    label: options[i],
                    onTap: () => Navigator.of(context).pop(i),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MgDialogButton(
                      label: cancelLabel,
                      onTap: () => Navigator.of(context).pop(),
                    ),
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

class _ChoiceRow extends StatefulWidget {
  const _ChoiceRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_ChoiceRow> createState() => _ChoiceRowState();
}

class _ChoiceRowState extends State<_ChoiceRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: _hover ? c.accent : const Color(0x00000000),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mgTextStyle(
                c,
                color: _hover ? c.onAccent : c.fg,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A macOS-style alert with one line of text to fill in, such as the
/// details of a report. Completes with the trimmed text, or null when
/// cancelled. Unless [allowEmpty], the main button waits for some text.
Future<String?> showMgPrompt(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String cancelLabel,
  String? message,
  String hint = '',
  bool allowEmpty = false,
}) => _showAlert<String>(
  context,
  _Prompt(
    title: title,
    message: message,
    hint: hint,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    allowEmpty: allowEmpty,
  ),
);

class _Prompt extends StatefulWidget {
  const _Prompt({
    required this.title,
    required this.message,
    required this.hint,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.allowEmpty,
  });

  final String title;
  final String? message;
  final String hint;
  final String confirmLabel;
  final String cancelLabel;
  final bool allowEmpty;

  @override
  State<_Prompt> createState() => _PromptState();
}

class _PromptState extends State<_Prompt> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _ready => widget.allowEmpty || _text.text.trim().isNotEmpty;

  void _confirm() {
    if (_ready) Navigator.of(context).pop(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final style = mgTextStyle(c);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
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
                widget.title,
                style: mgTextStyle(c, weight: FontWeight.w600),
              ),
              if (widget.message != null) ...[
                const SizedBox(height: 6),
                Text(widget.message!, style: mgTextStyle(c, color: c.fg2)),
              ],
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
                  controller: _text,
                  autofocus: true,
                  style: style,
                  cursorHeight: 15,
                  maxLength: 1024,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _confirm(),
                  decoration: InputDecoration.collapsed(
                    hintText: widget.hint,
                    hintStyle: style.copyWith(color: c.fg2),
                  ).copyWith(counterText: ''),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MgDialogButton(
                    label: widget.cancelLabel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    opacity: _ready ? 1 : 0.5,
                    duration: const Duration(milliseconds: 120),
                    child: MgDialogButton(
                      label: widget.confirmLabel,
                      filled: true,
                      color: c.accent,
                      onTap: _confirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A short notice over the bottom of the window, such as "Thank you, the
/// report is on its way": a glass pill that fades in, stays for
/// [duration] and fades out, as toasts do in Telegram for macOS.
void showMgToast(
  BuildContext context,
  String text, {
  Duration duration = const Duration(milliseconds: 2200),
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) =>
        _Toast(text: text, duration: duration, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.text,
    required this.duration,
    required this.onDone,
  });

  final String text;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
          reverseDuration: const Duration(milliseconds: 240),
        )
        ..forward()
        ..addStatusListener((status) {
          if (status == AnimationStatus.dismissed) widget.onDone();
        });

  late final _timer = Timer(widget.duration, () {
    if (mounted) _controller.reverse();
  });

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    return Positioned(
      left: 0,
      right: 0,
      bottom: 72,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(curved),
              child: Material(
                type: MaterialType.transparency,
                child: Glass(
                  radius: 16,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(widget.text, style: mgTextStyle(c)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
