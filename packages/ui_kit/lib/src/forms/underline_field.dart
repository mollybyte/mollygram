import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';

/// A text field drawn as a single underline, as on the official Telegram
/// sign-in screens: a hairline at rest, a 2 px accent line with focus, red
/// with an error.
class MgUnderlineField extends StatefulWidget {
  const MgUnderlineField({
    super.key,
    this.hintText,
    this.controller,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.errorText,
    this.textAlign = TextAlign.start,
    this.fontSize = 16,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.trailing,
  });

  /// Placeholder and accessible label. Pass a localized string.
  final String? hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool enabled;

  /// A field that only reacts to [onTap], like the country picker.
  final bool readOnly;

  /// Shown under the line in red.
  final String? errorText;
  final TextAlign textAlign;
  final double fontSize;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  /// A widget at the end of the line, such as a chevron.
  final Widget? trailing;

  static const Color errorColor = Color(0xFFFF3B30);

  @override
  State<MgUnderlineField> createState() => _MgUnderlineFieldState();
}

class _MgUnderlineFieldState extends State<MgUnderlineField> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
  }

  @override
  void didUpdateWidget(MgUnderlineField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _own)?.removeListener(_changed);
      _focus.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final style = mgTextStyle(c, size: widget.fontSize, height: 1.25);
    final error = widget.errorText;
    final focused = _focus.hasFocus && !widget.readOnly;
    final lineColor = error != null
        ? MgUnderlineField.errorColor
        : (focused ? c.accent : c.fg2.withValues(alpha: 0.3));
    final lineWidth = error != null || focused ? 2.0 : 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 40,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: lineColor, width: lineWidth),
            ),
          ),
          padding: EdgeInsets.only(bottom: 2 - lineWidth + 1),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  autofocus: widget.autofocus,
                  enabled: widget.enabled,
                  readOnly: widget.readOnly,
                  showCursor: !widget.readOnly,
                  mouseCursor: widget.readOnly
                      ? SystemMouseCursors.click
                      : null,
                  textAlign: widget.textAlign,
                  onTap: widget.onTap,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  autofillHints: widget.autofillHints,
                  style: style,
                  cursorHeight: widget.fontSize + 2,
                  decoration: InputDecoration.collapsed(
                    hintText: widget.hintText,
                    hintStyle: style.copyWith(color: c.fg2),
                  ),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: mgTextStyle(
              c,
              size: MgType.small,
              color: MgUnderlineField.errorColor,
            ),
          ),
        ],
      ],
    );
  }
}
