import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'providers.dart';

/// First name, last name and phone number of a new contact.
class AddContactForm extends ConsumerStatefulWidget {
  const AddContactForm({
    super.key,
    required this.onDone,
    required this.onCancel,
  });

  /// Called with the new contact's user id.
  final ValueChanged<int> onDone;
  final VoidCallback onCancel;

  @override
  ConsumerState<AddContactForm> createState() => _AddContactFormState();
}

class _AddContactFormState extends ConsumerState<AddContactForm> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  String? _firstError;
  String? _phoneError;

  /// Not tied to one field, such as a connection problem.
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final first = _first.text.trim();
    final phone = _phone.text.replaceAll(RegExp(r'[^\d+]'), '');
    setState(() {
      _firstError = first.isEmpty ? l10n.contactFirstNameRequired : null;
      _phoneError = phone.replaceAll('+', '').isEmpty
          ? l10n.contactPhoneRequired
          : null;
      _error = null;
    });
    if (_firstError != null || _phoneError != null) return;
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(contactsControllerProvider)
          .add(
            phoneNumber: phone,
            firstName: first,
            lastName: _last.text.trim(),
          );
      if (!mounted) return;
      switch (result) {
        case ContactAdded(:final userId):
          widget.onDone(userId);
        case NotOnTelegram():
          setState(() => _phoneError = l10n.contactNotOnTelegram);
      }
    } on Object {
      if (mounted) setState(() => _error = l10n.contactAddFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
      },
      child: FocusTraversalGroup(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              MgUnderlineField(
                controller: _first,
                hintText: l10n.contactFirstName,
                autofocus: true,
                fontSize: 14,
                errorText: _firstError,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_firstError != null) setState(() => _firstError = null);
                },
              ),
              const SizedBox(height: 14),
              MgUnderlineField(
                controller: _last,
                hintText: l10n.contactLastName,
                fontSize: 14,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              MgUnderlineField(
                controller: _phone,
                hintText: l10n.contactPhone,
                fontSize: 14,
                keyboardType: TextInputType.phone,
                errorText: _phoneError,
                onChanged: (_) {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: mgTextStyle(c, size: MgType.small, color: c.fg2),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MgTextButton(label: l10n.cancel, onPressed: widget.onCancel),
                  const SizedBox(width: 8),
                  MgPrimaryButton(
                    label: l10n.contactAdd,
                    loading: _saving,
                    onPressed: _submit,
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
