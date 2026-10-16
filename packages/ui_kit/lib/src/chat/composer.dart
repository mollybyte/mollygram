import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icon_button.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'composer_suggestions.dart';
import 'formatting.dart';
import 'link_sheet.dart';
import 'rich_text_controller.dart';
import 'selection_menu.dart';

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
    this.format,
  });

  /// The placeholder, "Message".
  final String hint;
  final String attach;
  final String emoji;
  final String record;
  final String send;

  /// The formatting items of the context menu and the link sheet; without
  /// them the shortcuts still work, except ⌘K.
  final FormatLabels? format;
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
    this.onSendMenu,
    this.extraButton,
    this.leading,
    this.onAttach,
    this.onAttachMenu,
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
    this.suggestions = const [],
    this.onSuggestion,
    this.onDismissSuggestions,
    this.suggestionsLift = 0,
  });

  final ComposerLabels labels;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Called with the draft when the send button is pressed or Enter is
  /// typed without Shift. The composer does not clear the draft itself.
  final ValueChanged<String>? onSend;

  /// A right click or long press on the send button, with the draft and
  /// where it happened, for other ways to send.
  final void Function(String text, Offset position)? onSendMenu;

  /// A button before the emoji one, such as the way to the chat's
  /// scheduled messages while it has some.
  final Widget? extraButton;

  /// A control before the attach button, such as a bot's menu button.
  final Widget? leading;
  final VoidCallback? onAttach;

  /// A click on the attach button, with the point above it where a menu
  /// of what to attach goes. Takes the place of [onAttach] when set.
  final void Function(Offset position)? onAttachMenu;
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

  /// Shown in a popup above the field, such as members matching an
  /// @mention. Up and Down move the highlight, Enter or Tab picks it
  /// ([onSuggestion]), Esc calls [onDismissSuggestions].
  final List<ComposerSuggestion> suggestions;
  final ValueChanged<int>? onSuggestion;
  final VoidCallback? onDismissSuggestions;

  /// How far above the composer the suggestions float, for a bar the
  /// parent lays out between them (a bot's reply keyboard).
  final double suggestionsLift;

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
    _suggestionsPortal.show();
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    if (!identical(old.suggestions, widget.suggestions)) _highlighted = 0;
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

  final _suggestionsPortal = OverlayPortalController();
  final _link = LayerLink();
  var _paneWidth = 320.0;

  bool _hadDraft = false;

  /// The suggestion Enter picks.
  var _highlighted = 0;

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

  KeyEventResult _onSuggestionKey(KeyEvent event) {
    final count = widget.suggestions.length;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlighted = (_highlighted + 1) % count);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _highlighted = (_highlighted - 1 + count) % count);
    } else if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.tab) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      widget.onSuggestion?.call(_highlighted.clamp(0, count - 1));
    } else if (key == LogicalKeyboardKey.escape &&
        widget.onDismissSuggestions != null) {
      widget.onDismissSuggestions!();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// The formatting shortcuts of TelegramSwift: ⌘B, ⌘I, ⌘U, ⌘⇧X, ⌘⇧M,
  /// ⌘⇧P, ⌘⇧. and ⌘K for a link on the selection.
  KeyEventResult _onFormatKey(KeyEvent event, RichTextEditingController text) {
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;
    final format = switch ((key, shift)) {
      (LogicalKeyboardKey.keyB, false) => TextFormat.bold,
      (LogicalKeyboardKey.keyI, false) => TextFormat.italic,
      (LogicalKeyboardKey.keyU, false) => TextFormat.underline,
      (LogicalKeyboardKey.keyX, true) => TextFormat.strikethrough,
      (LogicalKeyboardKey.keyM, true) => TextFormat.monospace,
      (LogicalKeyboardKey.keyP, true) => TextFormat.spoiler,
      (LogicalKeyboardKey.keyK, false) => TextFormat.link,
      _ when shift && event.physicalKey == PhysicalKeyboardKey.period =>
        TextFormat.quote,
      _ => null,
    };
    if (format == null) return KeyEventResult.ignored;
    if (format == TextFormat.link) {
      // With nothing selected ⌘K is left to the command palette.
      if (text.selection.isCollapsed || widget.labels.format == null) {
        return KeyEventResult.ignored;
      }
      unawaited(_askLink(text));
      return KeyEventResult.handled;
    }
    text.toggle(format);
    return KeyEventResult.handled;
  }

  Future<void> _askLink(RichTextEditingController text) async {
    final selection = text.selection;
    // Not prefilled from the clipboard: reading it without a paste would
    // make macOS ask the user for permission.
    final initial = text.selectedLink ?? '';
    final url = await showLinkSheet(
      context,
      labels: widget.labels.format!,
      initial: initial,
    );
    widget.focusNode?.requestFocus();
    if (url == null || !mounted) return;
    // The sheet took the focus; put the selection back before linking.
    text.selection = selection;
    text.setLink(url);
  }

  Widget _contextMenu(BuildContext context, EditableTextState state) {
    final labels = widget.labels.format;
    final text = _text;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final modifier = mac ? '\u2318' : 'Ctrl+';
    final shift = mac ? '\u21E7' : 'Shift+';
    void run(VoidCallback? action) {
      ContextMenuController.removeAny();
      action?.call();
    }

    String? shortcut(ContextMenuButtonType type) => switch (type) {
      ContextMenuButtonType.cut => '${modifier}X',
      ContextMenuButtonType.copy => '${modifier}C',
      ContextMenuButtonType.paste => '${modifier}V',
      ContextMenuButtonType.selectAll => '${modifier}A',
      _ => null,
    };
    final commands = [
      for (final item in state.contextMenuButtonItems)
        if (item.type != ContextMenuButtonType.custom)
          SelectionCommand(
            label: AdaptiveTextSelectionToolbar.getButtonLabel(context, item),
            shortcut: shortcut(item.type),
            onPressed: () => run(item.onPressed),
          ),
    ];
    final rich =
        labels != null &&
        text is RichTextEditingController &&
        !text.selection.isCollapsed;
    if (!rich) {
      return SelectionMenu(
        anchors: state.contextMenuAnchors,
        formats: const [],
        commands: commands,
      );
    }
    SelectionFormatButton format(
      TextFormat format,
      String name,
      String keys,
      Widget Function(Color color) glyph,
    ) => SelectionFormatButton(
      glyph: glyph,
      tooltip: '$name  $keys',
      active: text.isActive(format),
      onPressed: () => run(() => text.toggle(format)),
    );
    Widget letter(
      String value,
      Color color, {
      FontWeight? weight,
      FontStyle? style,
      TextDecoration? decoration,
    }) => selectionLetter(
      context,
      value,
      color,
      weight: weight,
      style: style,
      decoration: decoration,
    );
    return SelectionMenu(
      anchors: state.contextMenuAnchors,
      formats: [
        format(
          TextFormat.bold,
          labels.bold,
          '${modifier}B',
          (c) => letter('B', c, weight: FontWeight.w800),
        ),
        format(
          TextFormat.italic,
          labels.italic,
          '${modifier}I',
          (c) => letter('I', c, style: FontStyle.italic),
        ),
        format(
          TextFormat.underline,
          labels.underline,
          '${modifier}U',
          (c) => letter('U', c, decoration: TextDecoration.underline),
        ),
        format(
          TextFormat.strikethrough,
          labels.strikethrough,
          '$modifier${shift}X',
          (c) => letter('S', c, decoration: TextDecoration.lineThrough),
        ),
        format(
          TextFormat.monospace,
          labels.monospace,
          '$modifier${shift}M',
          (c) => selectionIcon(MgIcons.code, c),
        ),
        format(
          TextFormat.spoiler,
          labels.spoiler,
          '$modifier${shift}P',
          (c) => selectionIcon(MgIcons.spoiler, c),
        ),
        format(
          TextFormat.quote,
          labels.quote,
          '$modifier$shift.',
          (c) => selectionIcon(MgIcons.quote, c),
        ),
        SelectionFormatButton(
          glyph: (c) => selectionIcon(MgIcons.link, c),
          tooltip: '${labels.link}  ${modifier}K',
          active: text.selectedLink != null,
          onPressed: () => run(() => unawaited(_askLink(text))),
        ),
      ],
      commands: commands,
      extra: [
        SelectionCommand(
          label: labels.plain,
          onPressed: () => run(text.clearFormatting),
        ),
      ],
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (widget.suggestions.isNotEmpty &&
        (event is KeyDownEvent || event is KeyRepeatEvent)) {
      final result = _onSuggestionKey(event);
      if (result == KeyEventResult.handled) return result;
    }
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
    final text = _text;
    if (command &&
        !keyboard.isAltPressed &&
        text is RichTextEditingController) {
      // Undo and redo bring the formatting back with the text.
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.keyZ ||
          (!mac && key == LogicalKeyboardKey.keyY)) {
        final redo = key == LogicalKeyboardKey.keyY || keyboard.isShiftPressed;
        return text.prepareUndo(redo: redo)
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      }
      final result = _onFormatKey(event, text);
      if (result == KeyEventResult.handled) return result;
    }
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
      children: [
        Padding(
          padding: EdgeInsets.only(left: _leadingWidth),
          child: header,
        ),
        field,
      ],
    );
  }

  final _leadingKey = GlobalKey();
  double _leadingWidth = 0;

  void _measureLeading() {
    final width = widget.leading == null
        ? 0.0
        : (_leadingKey.currentContext?.size?.width ?? 0);
    if (width != _leadingWidth && mounted) {
      setState(() => _leadingWidth = width);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l = widget.labels;
    final style = mgTextStyle(c, size: MgType.title);
    final hasDraft = _text.text.trim().isNotEmpty || widget.allowEmpty;
    final replacing = widget.replacement != null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureLeading());
    final fieldRow = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.leading case final leading?)
          KeyedSubtree(key: _leadingKey, child: leading),
        Builder(
          builder: (context) => MgIconButton(
            icon: MgIcons.plus,
            iconSize: 22,
            size: MgSendButton.rowHeight,
            quiet: true,
            tooltip: l.attach,
            onPressed: switch (widget.onAttachMenu) {
              null => widget.onAttach,
              final onMenu => () {
                final box = context.findRenderObject()! as RenderBox;
                onMenu(box.localToGlobal(Offset(box.size.width / 2, 0)));
              },
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MgSendButton.rowHeight,
            ),
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
                  contextMenuBuilder: _contextMenu,
                  decoration: InputDecoration.collapsed(
                    hintText: l.hint,
                    hintStyle: style.copyWith(color: c.quiet),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ?widget.extraButton,
        MgIconButton(
          icon: MgIcons.emoji,
          iconSize: 22,
          size: MgSendButton.rowHeight,
          quiet: true,
          tooltip: l.emoji,
          onPressed: widget.onEmoji,
        ),
      ],
    );
    // A solid bar across the card's bottom, the card's own continuation
    // under a hairline.
    final composer = Container(
      decoration: BoxDecoration(
        color: c.solid(c.card),
        border: Border(top: BorderSide(color: c.separator)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
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
            const SizedBox(width: 8),
            // The square stays put and the glyph morphs: the new button
            // grows and fades in over the old one, which only fades at
            // the very end, so there is never a gap in the square.
            SizedBox(
              height: MgSendButton.rowHeight,
              child: Center(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : MgMotion.standard,
                  switchInCurve: MgMotion.enter,
                  switchOutCurve: Curves.linear,
                  transitionBuilder: (child, animation) {
                    final entering =
                        child.key == ValueKey(hasDraft ? 'send' : 'record');
                    if (!entering) {
                      return IgnorePointer(
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: const Interval(0, 0.15),
                          ),
                          child: child,
                        ),
                      );
                    }
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.7, end: 1.0).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: hasDraft
                      ? MgSendButton(
                          key: const ValueKey('send'),
                          tooltip: l.send,
                          onPressed: widget.onSend == null ? null : _send,
                          onMenu: widget.onSendMenu == null
                              ? null
                              : (position) =>
                                    widget.onSendMenu!(_text.text, position),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('record'),
                          child:
                              widget.recordButton ??
                              MgRecordButton(
                                tooltip: l.record,
                                onPressed: widget.onRecord,
                              ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final suggestions = widget.suggestions;
    // The list floats over the chat above the composer, so it never moves
    // the bot keyboard or the messages.
    return OverlayPortal(
      controller: _suggestionsPortal,
      overlayChildBuilder: (_) => CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: Offset(16, -6 - widget.suggestionsLift),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: suggestions.isEmpty
              ? const SizedBox.shrink()
              : TweenAnimationBuilder<double>(
                  key: const ValueKey('suggestions'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 6 * (1 - t)),
                      child: child,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.max(0, math.min(320, _paneWidth - 32)),
                    ),
                    child: ComposerSuggestionList(
                      suggestions: suggestions,
                      highlighted: _highlighted.clamp(
                        0,
                        suggestions.length - 1,
                      ),
                      onPick: (i) => widget.onSuggestion?.call(i),
                      onHover: (i) => setState(() => _highlighted = i),
                    ),
                  ),
                ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        // The list is no wider than its own pane, whatever the window.
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_paneWidth != constraints.maxWidth) {
              _paneWidth = constraints.maxWidth;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() {});
              });
            }
            return composer;
          },
        ),
      ),
    );
  }
}
