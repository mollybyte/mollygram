import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../../chat/message_tile.dart' show SenderAvatar;
import '../../contacts/providers.dart';
import '../settings_style.dart';

/// Picks people from the contacts, leaving out [exclude]. Completes with
/// the ids checked on [action], or null when cancelled.
Future<List<int>?> showUserPicker(
  BuildContext context, {
  required String title,
  required String action,
  Set<int> exclude = const {},
}) => showMgSheet<List<int>>(
  context,
  UserPicker(title: title, action: action, exclude: exclude),
);

class UserPicker extends ConsumerStatefulWidget {
  const UserPicker({
    super.key,
    required this.title,
    required this.action,
    this.exclude = const {},
  });

  final String title;
  final String action;
  final Set<int> exclude;

  @override
  ConsumerState<UserPicker> createState() => _UserPickerState();
}

class _UserPickerState extends ConsumerState<UserPicker> {
  final _checked = <int>[];
  final _search = FocusNode();
  var _query = '';

  @override
  void initState() {
    super.initState();
    _search.requestFocus();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop([..._checked]);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final contacts = ref.watch(contactsProvider).value;
    final shown = [
      for (final user in contacts ?? const <ContactUser>[])
        if (!widget.exclude.contains(user.id) &&
            (user.name.toLowerCase().contains(query) ||
                user.username.toLowerCase().contains(query)))
          user,
    ];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: SizedBox(
        width: 360,
        height: 500,
        child: Glass(
          radius: MgRadius.popover,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  widget.title,
                  style: mgTextStyle(c, weight: FontWeight.w600),
                ),
              ),
              MgSearchField(
                focusNode: _search,
                hintText: l10n.searchHint,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: contacts == null
                    ? const Center(child: SettingsSpinner())
                    : shown.isEmpty
                    ? Center(
                        child: Text(
                          l10n.nothingFound,
                          style: mgTextStyle(c, color: c.fg2),
                        ),
                      )
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final user = shown[i];
                          return _PickRow(
                            key: ValueKey(user.id),
                            user: user,
                            checked: _checked.contains(user.id),
                            onTap: () => setState(() {
                              if (!_checked.remove(user.id)) {
                                _checked.add(user.id);
                              }
                            }),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MgTextButton(
                    label: l10n.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 6),
                  MgTextButton(
                    label: widget.action,
                    onPressed: _checked.isEmpty ? null : _done,
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

class _PickRow extends StatefulWidget {
  const _PickRow({
    super.key,
    required this.user,
    required this.checked,
    required this.onTap,
  });

  final ContactUser user;
  final bool checked;
  final VoidCallback onTap;

  @override
  State<_PickRow> createState() => _PickRowState();
}

class _PickRowState extends State<_PickRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final user = widget.user;
    final motion = settingsMotionOf(context);
    return Semantics(
      checked: widget.checked,
      label: user.name,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: MgMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: _hover ? c.hover : c.hover.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                SenderAvatar(name: user.name, size: 30, photo: user.photo),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(c),
                  ),
                ),
                AnimatedContainer(
                  duration: motion,
                  curve: settingsCurve,
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.checked
                        ? c.accent
                        : c.accent.withValues(alpha: 0),
                    border: Border.all(
                      color: widget.checked ? c.accent : c.separator,
                      width: 1.5,
                    ),
                  ),
                  child: widget.checked
                      ? MgIcon(
                          checkIcon,
                          size: 12,
                          stroke: 2.4,
                          color: c.onAccent,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tick, for a checked row or the chosen option.
const checkIcon = MgIconData('check', '<path d="M5 12.5l4.5 4.5L19 7.5"/>');
