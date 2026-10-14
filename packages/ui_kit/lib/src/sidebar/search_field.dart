import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// The 30 px search field at the top of the sidebar.
class MgSearchField extends StatelessWidget {
  const MgSearchField({
    super.key,
    required this.hintText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  /// Placeholder and accessible label. Pass a localized string.
  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final style = mgTextStyle(c);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          MgIcon(MgIcons.search, size: 14, color: c.fg2),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: style,
              cursorHeight: 15,
              decoration: InputDecoration.collapsed(
                hintText: hintText,
                hintStyle: style.copyWith(color: c.fg2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
