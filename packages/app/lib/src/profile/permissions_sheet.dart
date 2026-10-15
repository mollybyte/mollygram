import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import 'manage_sheet.dart';
import 'member_sheets.dart';

/// What every member of a group may do, and slow mode: how long each
/// member waits between messages.
class PermissionsSheet extends ConsumerStatefulWidget {
  const PermissionsSheet({super.key, required this.settings});

  final ChatSettings settings;

  @override
  ConsumerState<PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends ConsumerState<PermissionsSheet> {
  late final _on = permissionsOf(widget.settings.permissions);
  late var _slowMode = widget.settings.slowModeDelay;
  var _busy = false;
  var _failed = false;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final management = ref
        .read(telegramSessionProvider)
        .requireValue
        .management;
    final settings = widget.settings;
    try {
      final permissions = memberPermissions(_on);
      if (_on != permissionsOf(settings.permissions)) {
        await management.setPermissions(settings.chatId, permissions);
      }
      if (_slowMode != settings.slowModeDelay) {
        await management.setSlowMode(settings.chatId, _slowMode);
      }
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final settings = widget.settings;
    return ManageSheetFrame(
      title: l10n.permissions,
      action: l10n.save,
      busy: _busy,
      error: _failed ? l10n.saveFailed : null,
      onAction: _busy ? null : _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetCaption(l10n.permissionsEveryone),
          for (final permission in MemberPermission.of(forum: settings.isForum))
            ToggleRow(
              label: permission.label(l10n),
              value: _on.contains(permission),
              onChanged: (on) => setState(
                () => on ? _on.add(permission) : _on.remove(permission),
              ),
            ),
          if (settings.isSupergroup) ...[
            SheetCaption(l10n.slowMode),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ChoiceRow<int>(
                value: _slowMode,
                onChanged: (value) => setState(() => _slowMode = value),
                options: [
                  for (final seconds in ChatManagement.slowModeDelays)
                    (seconds, describeSlowMode(l10n, seconds)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text(
                _slowMode == 0
                    ? l10n.slowModeOffNote
                    : l10n.slowModeNote(describeSlowMode(l10n, _slowMode)),
                style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Off", "10s", "1m", "1h".
String describeSlowMode(AppLocalizations l10n, int seconds) =>
    switch (seconds) {
      0 => l10n.off,
      < 60 => l10n.secondsShort(seconds),
      < 3600 => l10n.minutesShort(seconds ~/ 60),
      _ => l10n.hoursShort(seconds ~/ 3600),
    };
