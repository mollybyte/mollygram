import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';

/// A plain 34 px text field with the field fill, for forms such as sign-in.
class MgTextField extends StatelessWidget {
  const MgTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
  });

  /// Placeholder and accessible label. Pass a localized string.
  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool enabled;

  /// Shown under the field in red, and outlines the field.
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  static const Color _error = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final style = mgTextStyle(c, size: MgType.title);
    final error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: c.field,
            borderRadius: BorderRadius.circular(8),
            border: error == null ? null : Border.all(color: _error),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofocus: autofocus,
            enabled: enabled,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            autofillHints: autofillHints,
            style: style,
            cursorHeight: 16,
            decoration: InputDecoration.collapsed(
              hintText: hintText,
              hintStyle: style.copyWith(color: c.fg2),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(
            error,
            style: mgTextStyle(c, size: MgType.caption, color: _error),
          ),
        ],
      ],
    );
  }
}
