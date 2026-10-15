import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../glass/glass.dart';
import '../icon_button.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// Localized labels of the [Composer] buttons. The UI kit has no strings
/// of its own; the app passes them in.
@immutable
class ComposerLabels {
  const ComposerLabels({
    required this.hint,
    required this.attach,
    required this.emoji,
    required this.record,
    required this.send,
  });

  /// The placeholder, "Message".
  final String hint;
  final String attach;
  final String emoji;
  final String record;
  final String send;
}

/// The floating glass message composer: attach, the text field, emoji, and
/// the microphone that turns into a send button once there is a draft.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.labels,
    this.controller,
    this.focusNode,
    this.onSend,
    this.onAttach,
    this.onEmoji,
    this.onRecord,
    this.onCancel,
    this.onEditLast,
    this.onPaste,
    this.allowEmpty = false,
    this.header,
    this.recordButton,
    this.replacement,
    this.maxLines = 8,
  });

  final ComposerLabels labels;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Called with the draft when the send button is pressed or Enter is
  /// typed without Shift. The composer does not clear the draft itself.
  final ValueChanged<String>? onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onEmoji;
  final VoidCallback? onRecord;

  /// Esc in the text field, such as to stop replying or editing.
  final VoidCallback? onCancel;

  /// The up arrow in an empty field: edit the last message sent.
  final VoidCallback? onEditLast;

  /// Cmd+V (Ctrl+V elsewhere). Completes with true when it took what is
  /// on the clipboard, such as files or an image; otherwise the text on the
  /// clipboard is pasted as usual.
  final Future<bool> Function()? onPaste;

  /// Keeps the send button with an empty field, such as while editing a
  /// caption, which may be removed.
  final bool allowEmpty;

  /// Drawn above the text field inside the glass, such as the message
  /// being replied to.
  final Widget? header;

  /// Shown instead of the plain microphone while there is no draft, such
  /// as a button that records on press and hold.
  final Widget? recordButton;

  /// Shown in place of attach, the text field and emoji, such as the timer
  /// and live waveform of a recording. The send or record button stays,
  /// so a press that started on it keeps its pointer.
  final Widget? replacement;
  final int maxLines;

  /// The composer is at most 712 px wide, centered in the chat.
  static const double maxWidth = 712;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  TextEditingController? _own;
  TextEditingController get _text =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_changed);
      _text.addListener(_changed);
      _hadDraft = _text.text.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    _text.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  bool _hadDraft = false;

  void _changed() {
    final hasDraft = _text.text.trim().isNotEmpty;
    if (hasDraft != _hadDraft) setState(() => _hadDraft = hasDraft);
  }

  void _send() {
    final text = _text.text;
    if (text.trim().isEmpty && !widget.allowEmpty) return;
    widget.onSend?.call(text);
  }

  Future<void> _paste() async {
    if (await widget.onPaste!()) return;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.isEmpty || !mounted) return;
    final value = _text.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    // Like a native paste: the caret ends up after the pasted text.
    _text.value = TextEditingValue(
      text:
          selection.textBefore(value.text) +
          text +
          selection.textAfter(value.text),
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (widget.onSend != null &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    // Cmd+V on macOS, Ctrl+V elsewhere.
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final command = mac
        ? keyboard.isMetaPressed && !keyboard.isControlPressed
        : keyboard.isControlPressed && !keyboard.isMetaPressed;
    if (widget.onPaste != null &&
        event.logicalKey == LogicalKeyboardKey.keyV &&
        command &&
        !keyboard.isShiftPressed &&
        !keyboard.isAltPressed) {
      unawaited(_paste());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        widget.onCancel != null) {
      widget.onCancel!();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        widget.onEditLast != null &&
        _text.text.isEmpty) {
      widget.onEditLast!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _withHeader(Widget field) {
    final header = widget.header;
    if (header == null) return field;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, field],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l = widget.labels;
    final style = mgTextStyle(c, size: MgType.title);
    final hasDraft = _text.text.trim().isNotEmpty || widget.allowEmpty;
    final replacing = widget.replacement != null;
    final fieldRow = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        MgIconButton(
          icon: MgIcons.attach,
          tooltip: l.attach,
          iconSize: 18,
          onPressed: widget.onAttach,
        ),
        const SizedBox(width: 2),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Center(
              widthFactor: 1,
              child: Focus(
                onKeyEvent: _onKey,
                skipTraversal: true,
                child: TextField(
                  controller: _text,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  maxLines: widget.maxLines,
                  keyboardType: TextInputType.multiline,
                  style: style,
                  cursorHeight: 16,
                  decoration: InputDecoration.collapsed(
                    hintText: l.hint,
                    hintStyle: style.copyWith(color: c.fg2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        MgIconButton(
          icon: MgIcons.emoji,
          tooltip: l.emoji,
          iconSize: 18,
          onPressed: widget.onEmoji,
        ),
      ],
    );
    final composer = Glass(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      child: _withHeader(
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Stack(
                children: [
                  IgnorePointer(
                    ignoring: replacing,
                    child: AnimatedOpacity(
                      opacity: replacing ? 0 : 1,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      child: fieldRow,
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child:
                          widget.replacement ??
                          const SizedBox.shrink(key: ValueKey('none')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.6, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: hasDraft
                  ? MgSendButton(
                      key: const ValueKey('send'),
                      tooltip: l.send,
                      onPressed: widget.onSend == null ? null : _send,
                    )
                  : KeyedSubtree(
                      key: const ValueKey('record'),
                      child:
                          widget.recordButton ??
                          MgIconButton(
                            icon: MgIcons.mic,
                            tooltip: l.record,
                            iconSize: 18,
                            onPressed: widget.onRecord,
                          ),
                    ),
            ),
          ],
        ),
      ),
    );
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Composer.maxWidth),
        child: composer,
      ),
    );
  }
}
