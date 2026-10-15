import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../../chat/message_tile.dart' show SenderAvatar;
import '../settings_style.dart';
import '../settings_window.dart';
import 'privacy_page.dart';
import 'privacy_providers.dart';
import 'user_picker.dart';

/// Saves [choice] for [rule], reporting a failure with the "couldn't
/// save" text. The setting shown follows the controller, which keeps the
/// old choice when the save fails.
Future<String?> _save(
  WidgetRef ref,
  AppLocalizations l10n,
  PrivacyRule rule,
  PrivacyChoice choice,
) async {
  try {
    await ref.read(privacyControllerProvider).setChoice(rule, choice);
    return null;
  } on Object {
    return l10n.saveFailed;
  }
}

/// One privacy setting: who it is open to, then the people always and
/// never allowed. A click saves at once, as in System Settings.
class PrivacyRulePage extends ConsumerStatefulWidget {
  const PrivacyRulePage({super.key, required this.rule});

  final PrivacyRule rule;

  @override
  ConsumerState<PrivacyRulePage> createState() => _PrivacyRulePageState();
}

class _PrivacyRulePageState extends ConsumerState<PrivacyRulePage> {
  /// The audience being saved, shown right away.
  final _pending = <PrivacyRule, PrivacyAudience>{};
  String? _error;

  Future<void> _choose(
    PrivacyRule rule,
    PrivacyChoice current,
    PrivacyAudience audience,
  ) async {
    if (current.audience == audience) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _pending[rule] = audience;
      _error = null;
    });
    final error = await _save(
      ref,
      l10n,
      rule,
      current.copyWith(audience: audience),
    );
    if (!mounted) return;
    setState(() {
      _pending.remove(rule);
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rule = widget.rule;
    final choices = ref.watch(privacyChoicesProvider).value;
    final choice = choices?[rule];
    if (choice == null) {
      return const Center(child: SettingsSpinner());
    }
    final find = choices?[PrivacyRule.findByPhoneNumber];
    final audience = _pending[rule] ?? choice.audience;
    final shown = choice.copyWith(audience: audience);
    final about = rule.about(l10n);
    return SettingsPage(
      children: [
        _AudienceGroup(
          rule: rule,
          value: audience,
          footer: _error ?? (about.isEmpty ? null : about),
          error: _error != null,
          onChanged: (value) => unawaited(_choose(rule, choice, value)),
        ),
        // Who can find the user by number matters only while the number
        // itself is hidden from someone.
        if (rule == PrivacyRule.phoneNumber &&
            audience != PrivacyAudience.everybody &&
            find != null)
          _AudienceGroup(
            rule: PrivacyRule.findByPhoneNumber,
            value: _pending[PrivacyRule.findByPhoneNumber] ?? find.audience,
            footer: PrivacyRule.findByPhoneNumber.about(l10n),
            onChanged: (value) =>
                unawaited(_choose(PrivacyRule.findByPhoneNumber, find, value)),
          ),
        if (rule.hasExceptions)
          SettingsGroup(
            title: l10n.privacyExceptions,
            footer: SettingsFooter(l10n.privacyExceptionsAbout),
            children: [
              if (shown.showsAlways)
                _ExceptionsRow(rule: rule, always: true, choice: shown),
              if (shown.showsNever)
                _ExceptionsRow(rule: rule, always: false, choice: shown),
            ],
          ),
      ],
    );
  }
}

/// The question and a row per audience, the chosen one ticked.
class _AudienceGroup extends StatelessWidget {
  const _AudienceGroup({
    required this.rule,
    required this.value,
    required this.onChanged,
    this.footer,
    this.error = false,
  });

  final PrivacyRule rule;
  final PrivacyAudience value;
  final ValueChanged<PrivacyAudience> onChanged;
  final String? footer;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final footer = this.footer;
    return SettingsGroup(
      title: rule.question(l10n),
      footer: footer == null || footer.isEmpty
          ? null
          : SettingsFooter(footer, error: error),
      children: [
        for (final audience in rule.audiences)
          Semantics(
            selected: audience == value,
            child: SettingsRow(
              key: ValueKey((rule, audience)),
              title: audienceLabel(l10n, audience),
              trailing: AnimatedOpacity(
                duration: settingsMotionOf(context),
                opacity: audience == value ? 1 : 0,
                child: MgIcon(
                  checkIcon,
                  size: 15,
                  stroke: 2.3,
                  color: c.accent,
                ),
              ),
              onTap: () => onChanged(audience),
            ),
          ),
      ],
    );
  }
}

/// "Always allow" or "Never allow", with how many it holds.
class _ExceptionsRow extends StatelessWidget {
  const _ExceptionsRow({
    required this.rule,
    required this.always,
    required this.choice,
  });

  final PrivacyRule rule;
  final bool always;
  final PrivacyChoice choice;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final count = always ? choice.alwaysCount : choice.neverCount;
    final title = always ? l10n.privacyAlwaysAllow : l10n.privacyNeverAllow;
    return SettingsRow(
      key: ValueKey(always),
      title: title,
      trailing: Text(
        count == 0 ? l10n.privacyAddPeople : l10n.privacyPeopleCount(count),
        style: mgTextStyle(c, color: c.fg2),
      ),
      chevron: true,
      onTap: () => SettingsNavigation.of(context).push(
        title,
        (context) => PrivacyExceptionsPage(rule: rule, always: always),
      ),
    );
  }
}

/// The people and groups always or never allowed by [rule]: each with a
/// remove button, and a row to add people from the contacts.
class PrivacyExceptionsPage extends ConsumerStatefulWidget {
  const PrivacyExceptionsPage({
    super.key,
    required this.rule,
    required this.always,
  });

  final PrivacyRule rule;
  final bool always;

  @override
  ConsumerState<PrivacyExceptionsPage> createState() =>
      _PrivacyExceptionsPageState();
}

class _PrivacyExceptionsPageState extends ConsumerState<PrivacyExceptionsPage> {
  List<PrivacyPeer>? _peers;

  /// The ids [_peers] was described for.
  Object? _describedFor;
  String? _error;

  List<int> _users(PrivacyChoice choice) =>
      widget.always ? choice.alwaysUsers : choice.neverUsers;
  List<int> _chats(PrivacyChoice choice) =>
      widget.always ? choice.alwaysChats : choice.neverChats;

  void _describe(PrivacyChoice choice) {
    final key = Object.hashAll([..._users(choice), -1, ..._chats(choice)]);
    if (key == _describedFor) return;
    _describedFor = key;
    unawaited(
      ref
          .read(privacyControllerProvider)
          .describe(userIds: _users(choice), chatIds: _chats(choice))
          .then((peers) {
            if (mounted && key == _describedFor) {
              setState(() => _peers = peers);
            }
          }, onError: (_) {}),
    );
  }

  Future<void> _change(
    PrivacyChoice choice, {
    required List<int> users,
    required List<int> chats,
  }) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    final error = await _save(
      ref,
      l10n,
      widget.rule,
      widget.always
          ? choice.copyWith(alwaysUsers: users, alwaysChats: chats)
          : choice.copyWith(neverUsers: users, neverChats: chats),
    );
    if (mounted) setState(() => _error = error);
  }

  Future<void> _add(PrivacyChoice choice) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showUserPicker(
      context,
      title: widget.always ? l10n.privacyAlwaysAllow : l10n.privacyNeverAllow,
      action: l10n.folderAdd,
      exclude: _users(choice).toSet(),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    await _change(
      choice,
      users: [..._users(choice), ...picked],
      chats: _chats(choice),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final choice = ref.watch(privacyChoicesProvider).value?[widget.rule];
    if (choice == null) return const Center(child: SettingsSpinner());
    _describe(choice);
    final users = _users(choice);
    final chats = _chats(choice);
    final peers = [
      for (final peer in _peers ?? const <PrivacyPeer>[])
        if ((peer.isChat ? chats : users).contains(peer.id)) peer,
    ];
    return SettingsPage(
      children: [
        SettingsGroup(
          footer: _error == null
              ? SettingsFooter(
                  widget.always
                      ? l10n.privacyAlwaysAbout
                      : l10n.privacyNeverAbout,
                )
              : SettingsFooter(_error!, error: true),
          children: [
            SettingsRow(
              key: const ValueKey('add'),
              leading: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent.withValues(alpha: 0.12),
                ),
                child: MgIcon(
                  _plusIcon,
                  size: 16,
                  stroke: 2.2,
                  color: c.accent,
                ),
              ),
              title: l10n.privacyAddPeople,
              onTap: () => unawaited(_add(choice)),
            ),
            for (final peer in peers)
              SettingsRow(
                key: ValueKey((peer.isChat, peer.id)),
                leading: SenderAvatar(
                  name: peer.name,
                  size: 30,
                  photo: peer.photo,
                ),
                title: peer.name,
                subtitle: peer.isChat ? l10n.privacyGroupMembers : null,
                trailing: MgIconButton(
                  icon: MgIcons.close,
                  tooltip: l10n.folderRemove,
                  iconSize: 13,
                  onPressed: () => unawaited(
                    _change(
                      choice,
                      users: [
                        for (final id in users)
                          if (peer.isChat || id != peer.id) id,
                      ],
                      chats: [
                        for (final id in chats)
                          if (!peer.isChat || id != peer.id) id,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

const _plusIcon = MgIconData('plus', '<path d="M12 5v14M5 12h14"/>');
