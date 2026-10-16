import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_shell/mollygram_shell.dart' show usesCommandKey;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../../commands/command_registry.dart';
import '../../commands/shortcut_key.dart';
import '../preferences.dart';
import '../settings_style.dart';
import '../settings_window.dart';
import 'key_caps.dart';

/// The "Keyboard shortcuts" entry of the settings source list.
final shortcutsSection = SettingsSection(
  id: 'shortcuts',
  icon: _keyboard,
  tint: const Color(0xFF8E8E93),
  title: (l10n) => l10n.keyboardShortcuts,
  keywords: (l10n) => [l10n.shortcutsSearch, l10n.shortcutsRestoreAll],
  builder: (context) => const ShortcutsPage(),
);

/// How the list groups the actions.
enum ShortcutGroup { app, chat, navigation, accounts, plugins }

ShortcutGroup shortcutGroupOf(BindableAction action) => switch (action) {
  BindableAction(:final id) when id.startsWith('app.account.') =>
    ShortcutGroup.accounts,
  BindableAction(owner: 'shell') => ShortcutGroup.navigation,
  BindableAction(owner: 'plugins') => ShortcutGroup.plugins,
  BindableAction(:final id) when id.startsWith('plugin.') =>
    ShortcutGroup.plugins,
  BindableAction(owner: 'chat') => ShortcutGroup.chat,
  BindableAction(:final id) when id.startsWith('chat.') => ShortcutGroup.chat,
  _ => ShortcutGroup.app,
};

String _groupName(AppLocalizations l10n, ShortcutGroup group) =>
    switch (group) {
      ShortcutGroup.app => l10n.shortcutsGroupApp,
      ShortcutGroup.chat => l10n.shortcutsGroupChat,
      ShortcutGroup.navigation => l10n.shortcutsGroupNavigation,
      ShortcutGroup.accounts => l10n.shortcutsGroupAccounts,
      ShortcutGroup.plugins => l10n.shortcutsGroupPlugins,
    };

/// The user's keys after setting [key] for [id]: an override, or none
/// when it is the default again. Null [key] takes the key away.
Map<String, ShortcutKey?> withShortcut(
  Map<String, ShortcutKey?> overrides,
  BindableAction action,
  ShortcutKey? key,
) => {
  for (final MapEntry(key: id, :value) in overrides.entries)
    if (id != action.id) id: value,
  if (key != action.defaultKey) action.id: key,
};

/// A key that is already taken, waiting for Replace.
typedef _Conflict = ({String id, ShortcutKey key, String otherId});

/// Every command with its key, grouped, after System Settings' Keyboard
/// Shortcuts: click a key to record a new one, with a check against the
/// keys already in use.
class ShortcutsPage extends ConsumerStatefulWidget {
  const ShortcutsPage({super.key});

  @override
  ConsumerState<ShortcutsPage> createState() => _ShortcutsPageState();
}

class _ShortcutsPageState extends ConsumerState<ShortcutsPage> {
  final _search = TextEditingController();
  late final CommandRegistry _registry = ref.read(commandRegistryProvider);

  /// The action listening for its new key.
  String? _recording;

  /// Why the recorder didn't take the last key: a letter without a
  /// modifier, or a key the system keeps.
  String? _recordHint;
  _Conflict? _conflict;

  @override
  void initState() {
    super.initState();
    _search.addListener(_changed);
    _registry.addListener(_changed);
  }

  @override
  void dispose() {
    _registry.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _save(Map<String, ShortcutKey?> overrides) {
    ref
        .read(preferencesProvider.notifier)
        .update(
          (p) => p.copyWith(shortcuts: encodeShortcutOverrides(overrides)),
        );
    // The registry follows the preferences; it is set here too so the
    // list shows the change in this frame.
    _registry.overrides = overrides;
  }

  void _record(BindableAction action) => setState(() {
    _recording = action.id;
    _recordHint = null;
    _conflict = null;
  });

  void _stopRecording() {
    if (_recording == null) return;
    setState(() {
      _recording = null;
      _recordHint = null;
    });
  }

  void _onKey(BindableAction action, RecordedKey recorded) {
    switch (recorded) {
      case RecordingContinues():
        return;
      case RecordingNeedsModifier():
        final l10n = AppLocalizations.of(context);
        setState(
          () => _recordHint = usesCommandKey
              ? l10n.shortcutNeedsModifierMac
              : l10n.shortcutNeedsModifier,
        );
        return;
      case RecordingDone(:final key) when isReservedShortcut(key):
        final l10n = AppLocalizations.of(context);
        setState(
          () => _recordHint = usesCommandKey
              ? l10n.shortcutReservedMac
              : l10n.shortcutReserved,
        );
        return;
      case RecordingCancelled():
        _stopRecording();
      case RecordingCleared():
        _stopRecording();
        _save(withShortcut(_registry.overrides, action, null));
      case RecordingDone(:final key):
        _stopRecording();
        final other = _registry.whoUses(key, except: action.id);
        if (other != null) {
          setState(() => _conflict = (id: action.id, key: key, otherId: other));
          return;
        }
        _save(withShortcut(_registry.overrides, action, key));
    }
  }

  void _replace(_Conflict conflict, List<BindableAction> actions) {
    setState(() => _conflict = null);
    final action = actions.where((a) => a.id == conflict.id).firstOrNull;
    if (action == null) return;
    // The other action may be gone (a plugin turned off): its key is
    // taken back all the same.
    final other =
        actions.where((a) => a.id == conflict.otherId).firstOrNull ??
        BindableAction(id: conflict.otherId, owner: '', title: '');
    final freed = withShortcut(_registry.overrides, other, null);
    _save(withShortcut(freed, action, conflict.key));
  }

  /// Back to the default key, unless another action has it: then the
  /// same question as for a recorded key.
  void _restore(BindableAction action) {
    final key = action.defaultKey;
    final other = key == null
        ? null
        : _registry.whoUses(key, except: action.id);
    if (key != null && other != null) {
      setState(() => _conflict = (id: action.id, key: key, otherId: other));
      return;
    }
    setState(() => _conflict = null);
    _save({..._registry.overrides}..remove(action.id));
  }

  Future<void> _restoreAll() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.shortcutsRestoreAllTitle,
      message: l10n.shortcutsRestoreAllMessage,
      confirmLabel: l10n.shortcutsRestoreConfirm,
      cancelLabel: l10n.cancel,
    );
    if (confirmed == null || !mounted) return;
    setState(() => _conflict = null);
    _save(const {});
  }

  bool _matches(
    AppLocalizations l10n,
    BindableAction action,
    ShortcutKey? key,
    String query,
  ) {
    if (query.isEmpty) return true;
    return [
      action.title,
      ...action.keywords,
      _groupName(l10n, shortcutGroupOf(action)),
      ?key?.label,
    ].any((text) => text.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final actions = _registry.actions;
    final keys = _registry.effectiveKeys();
    final overrides = _registry.overrides;
    final query = _search.text.trim().toLowerCase();
    final groups = <ShortcutGroup, List<BindableAction>>{
      for (final group in ShortcutGroup.values) group: [],
    };
    for (final action in actions) {
      if (_matches(l10n, action, keys[action.id], query)) {
        groups[shortcutGroupOf(action)]!.add(action);
      }
    }
    String titleOf(String id) =>
        actions.where((a) => a.id == id).firstOrNull?.title ?? id;

    return SettingsPage(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: MgSearchField(
            hintText: l10n.shortcutsSearch,
            controller: _search,
          ),
        ),
        for (final MapEntry(key: group, value: list) in groups.entries)
          if (list.isNotEmpty)
            SettingsGroup(
              key: ValueKey(group),
              title: _groupName(l10n, group),
              children: [
                for (final action in list)
                  _ShortcutRow(
                    key: ValueKey(('shortcut', action.id)),
                    action: action,
                    shortcut: keys[action.id],
                    changed:
                        overrides.containsKey(action.id) &&
                        overrides[action.id] != action.defaultKey,
                    recording: _recording == action.id,
                    hint: _recording == action.id ? _recordHint : null,
                    conflict: _conflict?.id == action.id ? _conflict : null,
                    conflictTitle: _conflict?.id == action.id
                        ? titleOf(_conflict!.otherId)
                        : null,
                    onRecord: () => _record(action),
                    onKey: (recorded) => _onKey(action, recorded),
                    onCancel: _stopRecording,
                    onRestore: () => _restore(action),
                    onReplace: () => _replace(_conflict!, actions),
                    onDismissConflict: () => setState(() => _conflict = null),
                  ),
              ],
            ),
        if (groups.values.every((list) => list.isEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              l10n.nothingFound,
              textAlign: TextAlign.center,
              style: mgTextStyle(c, color: c.fg2),
            ),
          ),
        SettingsGroup(
          footer: SettingsFooter(l10n.shortcutsHint),
          children: [
            SettingsRow(
              key: const ValueKey('restoreAllShortcuts'),
              title: l10n.shortcutsRestoreAll,
              onTap: overrides.isEmpty ? null : () => unawaited(_restoreAll()),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget implements SettingsGroupRow {
  const _ShortcutRow({
    super.key,
    required this.action,
    required this.shortcut,
    required this.changed,
    required this.recording,
    required this.hint,
    required this.conflict,
    required this.conflictTitle,
    required this.onRecord,
    required this.onKey,
    required this.onCancel,
    required this.onRestore,
    required this.onReplace,
    required this.onDismissConflict,
  });

  final BindableAction action;
  final ShortcutKey? shortcut;

  /// The user's key differs from the default.
  final bool changed;
  final bool recording;

  /// Why the recorder didn't take the last key.
  final String? hint;
  final _Conflict? conflict;
  final String? conflictTitle;
  final VoidCallback onRecord;
  final ValueChanged<RecordedKey> onKey;
  final VoidCallback onCancel;
  final VoidCallback onRestore;
  final VoidCallback onReplace;
  final VoidCallback onDismissConflict;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final conflict = this.conflict;
    final Widget value;
    if (recording) {
      value = ShortcutRecorder(
        hint: l10n.shortcutRecording,
        onKey: onKey,
        onCancel: onCancel,
      );
    } else if (conflict != null) {
      value = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KeyCaps(conflict.key),
          const SizedBox(width: 8),
          SettingsButton(
            key: const ValueKey('replaceShortcut'),
            label: l10n.shortcutReplace,
            onPressed: onReplace,
          ),
          const SizedBox(width: 6),
          SettingsButton(label: l10n.cancel, onPressed: onDismissConflict),
        ],
      );
    } else {
      final shortcut = this.shortcut;
      value = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (changed) ...[
            MgIconButton(
              key: ValueKey(('restoreShortcut', action.id)),
              icon: _restoreIcon,
              tooltip: l10n.shortcutRestore,
              iconSize: 14,
              onPressed: onRestore,
            ),
            const SizedBox(width: 4),
          ],
          Tooltip(
            message: l10n.shortcutChange,
            waitDuration: const Duration(milliseconds: 600),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: ValueKey(('recordShortcut', action.id)),
                behavior: HitTestBehavior.opaque,
                onTap: onRecord,
                child: Container(
                  height: KeyCaps.rowHeight,
                  alignment: Alignment.center,
                  child: shortcut == null
                      ? Text(
                          l10n.shortcutNone,
                          style: mgTextStyle(c, color: c.fg2),
                        )
                      : KeyCaps(shortcut),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return SettingsRow(
      title: action.title,
      subtitle: conflict != null
          ? l10n.shortcutUsedBy(conflictTitle ?? '')
          : hint,
      trailing: AnimatedSize(
        duration: settingsMotionOf(context),
        curve: settingsCurve,
        alignment: Alignment.centerRight,
        child: AnimatedSwitcher(
          duration: settingsMotionOf(context),
          child: KeyedSubtree(
            key: ValueKey((recording, conflict?.key, shortcut, changed)),
            child: value,
          ),
        ),
      ),
    );
  }
}

const _keyboard = MgIconData(
  'keyboard',
  '<rect x="3" y="6" width="18" height="12" rx="2.5"/>'
      '<path d="M7 10h.01M10.5 10h.01M14 10h.01M17 10h.01M8 14h8"/>',
);
const _restoreIcon = MgIconData(
  'restore',
  '<path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3M4.5 4v3.5H8"/>',
);
