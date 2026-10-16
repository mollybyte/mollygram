import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../settings_style.dart';

/// One field of a [FormSheet].
@immutable
final class FormSheetField {
  const FormSheetField(
    this.hint, {
    this.obscure = false,
    this.optional = false,
    this.keyboardType,
    this.submitAtLength = 0,
  });

  final String hint;
  final bool obscure;

  /// May stay empty; the action waits for the other fields only.
  final bool optional;
  final TextInputType? keyboardType;

  /// A code of this many characters submits the sheet once typed; 0 never.
  final int submitAtLength;
}

/// Shows a small sheet of [fields] with [action]. [onSubmit] gets the
/// values in order and returns an error to show under the fields, or null
/// to close. [aside], such as "Forgot password?", sits left of the
/// buttons: it closes the sheet, then runs. Completes with whether the
/// sheet was submitted.
Future<bool> showFormSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<FormSheetField> fields,
  required String action,
  bool destructive = false,
  required Future<String?> Function(List<String> values) onSubmit,
  FormSheetAside? aside,
}) async {
  final result = await showMgSheet<Object>(
    context,
    FormSheet(
      title: title,
      subtitle: subtitle,
      fields: fields,
      action: action,
      destructive: destructive,
      onSubmit: onSubmit,
      aside: aside,
    ),
  );
  if (result == FormSheet.asideChosen) await aside?.onTap();
  return result == true;
}

/// A link under a [FormSheet]'s fields that leads away from it.
typedef FormSheetAside = ({String label, Future<void> Function() onTap});

class FormSheet extends StatefulWidget {
  const FormSheet({
    super.key,
    required this.title,
    required this.fields,
    required this.action,
    required this.onSubmit,
    this.subtitle,
    this.destructive = false,
    this.aside,
  });

  /// What the sheet closes with when [aside] is clicked.
  static const asideChosen = #aside;

  final String title;
  final String? subtitle;
  final List<FormSheetField> fields;
  final String action;
  final bool destructive;
  final Future<String?> Function(List<String> values) onSubmit;
  final FormSheetAside? aside;

  @override
  State<FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<FormSheet> {
  late final _controllers = [
    for (final _ in widget.fields) TextEditingController(),
  ];
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _ready => [
    for (var i = 0; i < widget.fields.length; i++)
      widget.fields[i].optional || _controllers[i].text.trim().isNotEmpty,
  ].every((ready) => ready);

  Future<void> _submit() async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit([
      for (final controller in _controllers) controller.text,
    ]);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final subtitle = widget.subtitle;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(false),
      },
      child: SizedBox(
        width: 340,
        child: Glass(
          radius: MgRadius.popover,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: mgTextStyle(c, weight: FontWeight.w600),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: mgTextStyle(
                    c,
                    size: MgType.caption,
                    color: c.fg2,
                    height: 1.35,
                  ),
                ),
              ],
              for (var i = 0; i < widget.fields.length; i++) ...[
                const SizedBox(height: 12),
                MgUnderlineField(
                  controller: _controllers[i],
                  hintText: widget.fields[i].hint,
                  obscureText: widget.fields[i].obscure,
                  keyboardType: widget.fields[i].keyboardType,
                  autofocus: i == 0,
                  fontSize: 14,
                  enabled: !_busy,
                  onChanged: (text) {
                    setState(() => _error = null);
                    final length = widget.fields[i].submitAtLength;
                    if (length > 0 && text.trim().length == length) {
                      unawaited(_submit());
                    }
                  },
                  onSubmitted: (_) => unawaited(_submit()),
                ),
              ],
              AnimatedSize(
                duration: MgMotion.standard,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: mgTextStyle(
                            c,
                            size: MgType.caption,
                            color: MgDestructive.color,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.aside case final aside?) ...[
                    MgTextButton(
                      key: const ValueKey('formSheetAside'),
                      label: aside.label,
                      onPressed: _busy
                          ? null
                          : () =>
                                Navigator.of(context)
                                    .pop(FormSheet.asideChosen),
                    ),
                    const Spacer(),
                  ],
                  SettingsButton(
                    label: l10n.cancel,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 8),
                  SettingsButton(
                    label: widget.action,
                    destructive: widget.destructive,
                    onPressed: _busy || !_ready
                        ? null
                        : () => unawaited(_submit()),
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
