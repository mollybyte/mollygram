import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';

/// Shows [sheet] over the window, with the short eased entrance of the
/// other sheets; the window is not dimmed.
Future<T?> showManageSheet<T>(BuildContext context, Widget sheet) =>
    showMgSheet<T>(context, sheet);

/// The glass card of a management sheet: a title row, the [child] and,
/// at the bottom, Cancel and the main action. Esc cancels.
class ManageSheetFrame extends StatelessWidget {
  const ManageSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.action,
    this.onAction,
    this.busy = false,
    this.error,
    this.height,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;

  /// The main button, such as Save; none when null.
  final String? action;
  final VoidCallback? onAction;
  final bool busy;

  /// Shown above the buttons when the last attempt failed.
  final String? error;

  /// A fixed height for sheets with lists; otherwise as tall as needed.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    void cancel() => Navigator.of(context).pop();
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              if (onBack != null)
                MgIconButton(
                  icon: MgIcons.back,
                  tooltip: l10n.back,
                  iconSize: 16,
                  onPressed: onBack,
                )
              else
                const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(c, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (height == null) child else Expanded(child: child),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error!,
            style: mgTextStyle(c, size: MgType.small, color: c.fg2),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            MgTextButton(
              label: action == null ? l10n.close : l10n.cancel,
              onPressed: cancel,
            ),
            if (action != null) ...[
              const SizedBox(width: 8),
              MgPrimaryButton(
                label: action!,
                loading: busy,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ],
    );
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): cancel},
      child: FocusScope(
        autofocus: true,
        child: SizedBox(
          width: 360,
          height: height,
          child: Glass(
            radius: MgRadius.popover,
            padding: const EdgeInsets.fromLTRB(
              MgSpace.ml,
              MgSpace.m,
              MgSpace.ml,
              MgSpace.ml,
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// A caption over a group of rows, in the sentence case of the app.
class SheetCaption extends StatelessWidget {
  const SheetCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: Text(
        text,
        style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
      ),
    );
  }
}

/// A row with a label and a switch, like a right in TelegramSwift's
/// administrator screen. A click anywhere on the row flips it.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  });

  final String label;
  final bool value;

  /// Null when the user can't change it.
  final ValueChanged<bool>? onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: mgTextStyle(c, color: enabled ? c.fg : c.fg2),
                  ),
                ),
                _Switch(value: value, enabled: enabled),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small macOS switch: the accent track when on, a grey one when off.
class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.enabled});

  final bool value;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    const duration = Duration(milliseconds: 160);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        width: 30,
        height: 18,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? c.accent : c.separator,
          borderRadius: BorderRadius.circular(9),
        ),
        child: AnimatedAlign(
          duration: duration,
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }
}

/// A choice of a few short options in one row, such as how long a link
/// works.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          for (final (option, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: option == value,
                label: label,
                excludeSemantics: true,
                child: MouseRegion(
                  cursor: onChanged == null
                      ? MouseCursor.defer
                      : SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onChanged == null ? null : () => onChanged!(option),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: option == value
                            ? c.windowBackground
                            : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(
                          c,
                          size: MgType.small,
                          color: onChanged == null ? c.fg2 : c.fg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A person in a management list: avatar, name, a line under it and
/// short actions on the right, such as Approve and Dismiss.
class PersonRow extends StatefulWidget {
  const PersonRow({
    super.key,
    required this.name,
    required this.avatar,
    this.subtitle = '',
    this.actions = const [],
    this.onTap,
  });

  final String name;
  final Widget avatar;
  final String subtitle;

  /// Label and what it does; a destructive one goes last.
  final List<(String, VoidCallback)> actions;
  final VoidCallback? onTap;

  @override
  State<PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<PersonRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: _hover && widget.onTap != null
                ? c.hover
                : const Color(0x00000000),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              widget.avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(c, height: 1.3),
                    ),
                    if (widget.subtitle.isNotEmpty)
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(
                          c,
                          size: MgType.caption,
                          color: c.fg2,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
              for (final (label, action) in widget.actions)
                MgTextButton(label: label, onPressed: action),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a sheet shows while its list loads, when it failed, or when
/// there is nothing in it.
class SheetNotice extends StatelessWidget {
  const SheetNotice(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: mgTextStyle(c, color: c.fg2),
        ),
      ),
    );
  }
}
