import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../chat/message_tile.dart' show SenderAvatar;
import '../session/accounts.dart';
import '../session/providers.dart';
import 'settings_style.dart';
import 'settings_window.dart';

/// The signed-in user's profile. Edits invalidate it to read it again.
final accountProfileProvider = FutureProvider.autoDispose<AccountProfile>(
  (ref) => ref.watch(telegramSessionProvider).requireValue.account.profile(),
);

/// Signs out of the open account and wipes what it kept here; the next
/// account opens, or sign-in when it was the only one.
final logOutProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final index = await ref.read(accountsProvider.future);
    await ref.read(accountsProvider.notifier).logOut(index.active);
  },
);

/// "+79991234567" for TDLib's digits; TDLib gives no grouping.
String formatPhone(String digits) => digits.isEmpty ? '' : '+$digits';

/// The account card at the top of the source list: photo, name and phone.
class AccountCard extends ConsumerStatefulWidget {
  const AccountCard({super.key, required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  ConsumerState<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<AccountCard> {
  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final profile = ref.watch(accountProfileProvider).value;
    final selected = widget.selected;
    final name = profile?.name ?? '';
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: MgPressable(
        scale: 1,
        onTap: widget.onTap,
        builder: (context, state) => SettingsSidebarTile(
          selected: selected,
          hover: state.hovered,
          pressed: state.pressed,
          height: 64,
          child: Row(
            children: [
              SenderAvatar(name: name, size: 44, photo: profile?.photo),
              const SizedBox(width: MgSpace.ml),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(
                        c,
                        size: MgType.title,
                        weight: MgWeight.medium,
                        color: selected ? c.onAccent : null,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      formatPhone(profile?.phoneNumber ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(
                        c,
                        size: MgType.small,
                        color: selected ? c.onAccentSecondary : c.fg2,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// My profile: photo, name, username, bio and phone, then Log out.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(accountProfileProvider)) {
      AsyncData(:final value) => _AccountForm(profile: value),
      AsyncError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.profileFailed, style: mgTextStyle(c, color: c.fg2)),
            const SizedBox(height: 10),
            SettingsButton(
              label: l10n.tryAgain,
              onPressed: () => ref.invalidate(accountProfileProvider),
            ),
          ],
        ),
      ),
      _ => const Center(child: SettingsSpinner(size: 18)),
    };
  }
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({required this.profile});

  final AccountProfile profile;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

/// What the footer under the username says.
sealed class _UsernameNote {
  const _UsernameNote();
}

class _UsernameHint extends _UsernameNote {
  const _UsernameHint();
}

class _UsernameChecking extends _UsernameNote {
  const _UsernameChecking();
}

class _UsernameIssue extends _UsernameNote {
  const _UsernameIssue(this.issue);

  final UsernameIssue issue;
}

class _UsernameAnswer extends _UsernameNote {
  const _UsernameAnswer(this.name, this.availability);

  final String name;
  final UsernameAvailability availability;
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  String? _nameError;
  String? _bioError;
  String? _usernameError;
  _UsernameNote _usernameNote = const _UsernameHint();
  Timer? _usernameCheck;
  var _bioLength = 0;
  var _bioFocused = false;
  var _loggingOut = false;
  String? _logOutError;

  /// Both name fields as typed: Telegram takes first and last name in one
  /// request, so an edit to one must not send the other's old value.
  late String _firstDraft = _profile.firstName;
  late String _lastDraft = _profile.lastName;

  /// Bumped on every edit, so a check answered after the text changed is
  /// dropped.
  int _usernameGeneration = 0;

  AccountProfile get _profile => widget.profile;

  // Kept from when the page was built: a field still being edited is
  // saved as the page goes away, when context and ref can't be used.
  late final AccountSettings _account;
  late ProviderContainer _container;
  late AppLocalizations _l10n;

  @override
  void initState() {
    super.initState();
    _account = ref.read(telegramSessionProvider).requireValue.account;
    _bioLength = _profile.bio.characters.length;
  }

  @override
  void didUpdateWidget(_AccountForm old) {
    super.didUpdateWidget(old);
    // A fresh profile replaces a draft only where it wasn't edited.
    if (_firstDraft == old.profile.firstName) {
      _firstDraft = _profile.firstName;
    }
    if (_lastDraft == old.profile.lastName) _lastDraft = _profile.lastName;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
    _l10n = AppLocalizations.of(context);
  }

  @override
  void dispose() {
    _usernameCheck?.cancel();
    super.dispose();
  }

  /// Sends a change and reads the profile again. Returns the message to
  /// show when Telegram refuses it.
  Future<String?> _save(Future<void> Function() request) async {
    try {
      await request();
      _container.invalidate(accountProfileProvider);
      return null;
    } catch (_) {
      return _l10n.saveFailed;
    }
  }

  Future<bool> _saveName({String? first, String? last}) async {
    if (first != null) _firstDraft = first;
    if (last != null) _lastDraft = last;
    final firstName = _firstDraft.trim();
    if (firstName.isEmpty) {
      if (mounted) setState(() => _nameError = _l10n.firstNameRequired);
      return false;
    }
    final lastName = _lastDraft;
    final error = await _save(() => _account.setName(firstName, lastName));
    if (mounted) setState(() => _nameError = error);
    return error == null;
  }

  Future<bool> _saveBio(String bio) async {
    final error = await _save(() => _account.setBio(bio));
    if (mounted) setState(() => _bioError = error);
    return error == null;
  }

  void _usernameChanged(String value) {
    _usernameCheck?.cancel();
    final generation = ++_usernameGeneration;
    final name = value.trim();
    setState(() => _usernameError = null);
    if (name.isEmpty || name.toLowerCase() == _profile.username.toLowerCase()) {
      setState(() => _usernameNote = const _UsernameHint());
      return;
    }
    final issue = usernameIssue(name);
    if (issue != null) {
      setState(() => _usernameNote = _UsernameIssue(issue));
      return;
    }
    setState(() => _usernameNote = const _UsernameChecking());
    _usernameCheck = Timer(const Duration(milliseconds: 350), () async {
      UsernameAvailability answer;
      try {
        answer = await _account.checkUsername(_profile.userId, name);
      } catch (_) {
        answer = UsernameAvailability.unavailable;
      }
      if (!mounted || _usernameGeneration != generation) return;
      setState(() => _usernameNote = _UsernameAnswer(name, answer));
    });
  }

  Future<bool> _saveUsername(String value) async {
    final name = value.trim();
    if (name.isNotEmpty && !await _isFree(name)) return false;
    final error = await _save(() => _account.setUsername(name));
    if (!mounted) return false;
    setState(() {
      _usernameError = error;
      if (error == null) _usernameNote = const _UsernameHint();
    });
    return error == null;
  }

  /// Whether Telegram takes [name]. A check still waiting for its pause,
  /// such as when the page closes right after typing, runs now.
  Future<bool> _isFree(String name) async {
    if (usernameIssue(name) != null) return false;
    final note = _usernameNote;
    if (note is _UsernameAnswer && note.name == name) {
      return note.availability == UsernameAvailability.available;
    }
    _usernameCheck?.cancel();
    final generation = _usernameGeneration;
    UsernameAvailability answer;
    try {
      answer = await _account.checkUsername(_profile.userId, name);
    } catch (_) {
      answer = UsernameAvailability.unavailable;
    }
    if (mounted && _usernameGeneration == generation) {
      setState(() => _usernameNote = _UsernameAnswer(name, answer));
    }
    return answer == UsernameAvailability.available;
  }

  Widget _usernameFooter(AppLocalizations l10n) {
    final error = _usernameError;
    if (error != null) return SettingsFooter(error, error: true);
    return switch (_usernameNote) {
      _UsernameHint() => SettingsFooter(l10n.usernameHint),
      _UsernameChecking() => SettingsFooter(l10n.usernameChecking),
      _UsernameIssue(:final issue) => SettingsFooter(switch (issue) {
        UsernameIssue.tooShort => l10n.usernameTooShort,
        UsernameIssue.tooLong => l10n.usernameTooLong,
        UsernameIssue.invalidCharacter => l10n.usernameInvalidCharacter,
        UsernameIssue.startsWithLetter => l10n.usernameStartsWithLetter,
        UsernameIssue.endsWithUnderscore => l10n.usernameEndsWithUnderscore,
      }, error: true),
      _UsernameAnswer(:final name, :final availability) => SettingsFooter(
        switch (availability) {
          UsernameAvailability.available => l10n.usernameAvailable(name),
          UsernameAvailability.occupied => l10n.usernameOccupied,
          UsernameAvailability.purchasable => l10n.usernamePurchasable,
          UsernameAvailability.invalid => l10n.usernameInvalidCharacter,
          UsernameAvailability.unavailable => l10n.usernameUnavailable,
        },
        error: availability != UsernameAvailability.available,
        success: availability == UsernameAvailability.available,
      ),
    };
  }

  Future<void> _logOut() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.logOutTitle,
      message: l10n.logOutMessage,
      confirmLabel: l10n.logOut,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null || !mounted) return;
    setState(() {
      _loggingOut = true;
      _logOutError = null;
    });
    try {
      // On success the account is gone and this page with it.
      await ref.read(logOutProvider)();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loggingOut = false;
        _logOutError = l10n.logOutFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final p = _profile;
    final handle = p.username.isEmpty ? '' : '@${p.username}';
    final remaining = p.bioLimit - _bioLength;
    return SettingsPage(
      children: [
        const SizedBox(height: 8),
        Center(
          child: SenderAvatar(name: p.name, size: 72, photo: p.photo),
        ),
        const SizedBox(height: 10),
        Text(
          p.name,
          textAlign: TextAlign.center,
          style: mgTextStyle(
            c,
            size: 19,
            weight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          [
            formatPhone(p.phoneNumber),
            handle,
          ].where((s) => s.isNotEmpty).join('  ·  '),
          textAlign: TextAlign.center,
          style: mgTextStyle(c, color: c.fg2),
        ),
        SettingsGroup(
          footer: _nameError == null
              ? null
              : SettingsFooter(_nameError!, error: true),
          children: [
            _FieldRow(
              key: const ValueKey('firstName'),
              label: l10n.firstName,
              value: p.firstName,
              maxLength: 64,
              onChanged: (v) => _firstDraft = v,
              onCommit: (v) => _saveName(first: v),
            ),
            _FieldRow(
              key: const ValueKey('lastName'),
              label: l10n.lastName,
              value: p.lastName,
              maxLength: 64,
              onChanged: (v) => _lastDraft = v,
              onCommit: (v) => _saveName(last: v),
            ),
          ],
        ),
        SettingsGroup(
          footer: _usernameFooter(l10n),
          children: [
            _FieldRow(
              key: const ValueKey('username'),
              label: l10n.username,
              value: p.username,
              prefix: '@',
              maxLength: 32,
              onChanged: _usernameChanged,
              onCommit: _saveUsername,
            ),
          ],
        ),
        SettingsGroup(
          footer: SettingsFooter(
            _bioError ?? l10n.bioHint,
            error: _bioError != null,
          ),
          children: [
            _FieldRow(
              key: const ValueKey('bio'),
              placeholder: l10n.bio,
              value: p.bio,
              maxLength: p.bioLimit,
              onChanged: (v) =>
                  setState(() => _bioLength = v.characters.length),
              onFocusChanged: (f) => setState(() => _bioFocused = f),
              trailing: AnimatedOpacity(
                duration: settingsMotionOf(context),
                opacity: _bioFocused ? 1 : 0,
                child: Text(
                  '$remaining',
                  style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
                ),
              ),
              onCommit: _saveBio,
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsRow(
              title: l10n.phoneNumber,
              trailing: Text(
                formatPhone(p.phoneNumber),
                style: mgTextStyle(c, color: c.fg2),
              ),
            ),
          ],
        ),
        const AccountsGroup(),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: SettingsButton(
            label: l10n.logOutButton,
            onPressed: _loggingOut ? null : _logOut,
          ),
        ),
        if (_logOutError != null)
          Align(
            alignment: Alignment.centerRight,
            child: SettingsFooter(_logOutError!, error: true),
          ),
      ],
    );
  }
}

/// The accounts on this computer: click one to switch to it, log out of
/// the others here (the open one has the button below), or add one.
class AccountsGroup extends ConsumerStatefulWidget {
  const AccountsGroup({super.key});

  @override
  ConsumerState<AccountsGroup> createState() => _AccountsGroupState();
}

class _AccountsGroupState extends ConsumerState<AccountsGroup> {
  String? _error;

  Future<void> _logOut(AccountEntry account, String title) async {
    final l10n = AppLocalizations.of(context);
    // Always asked: an entry rebuilt after the index was lost may still
    // be signed in.
    final confirmed = await showMgConfirm(
      context,
      title: l10n.logOutAccountTitle(title),
      message: l10n.logOutMessage,
      confirmLabel: l10n.logOut,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null || !mounted) return;
    setState(() => _error = null);
    try {
      await ref.read(accountsProvider.notifier).logOut(account.slot);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.logOutFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = ref.watch(accountsProvider).value;
    if (index == null) return const SizedBox.shrink();
    final busy = ref.watch(accountsActivityProvider) != null;
    final notifier = ref.read(accountsProvider.notifier);
    final canAdd = AccountsNotifier.canAddIn(index);
    final footer = _error != null
        ? SettingsFooter(_error!, error: true)
        : SettingsFooter(
            index.legacy
                ? l10n.accountsLegacy
                : canAdd
                ? l10n.accountsAbout(AccountStorage.maxAccounts)
                : l10n.accountsFull(AccountStorage.maxAccounts),
          );
    return SettingsGroup(
      key: const ValueKey('accounts'),
      title: l10n.accounts,
      footer: footer,
      children: [
        for (final (i, account) in index.accounts.indexed)
          _AccountRow(
            account: account,
            number: i + 1,
            isActive: account.slot == index.active,
            enabled: !busy && !index.legacy,
            onSwitch: () => unawaited(notifier.switchTo(account.slot)),
            onLogOut: (title) => unawaited(_logOut(account, title)),
          ),
        SettingsRow(
          key: const ValueKey('addAccount'),
          leading: MgIcon(
            MgIcons.plus,
            size: 16,
            color: MgColors.of(context).accent,
          ),
          title: l10n.addAccount,
          onTap: canAdd && !busy ? () => unawaited(notifier.add()) : null,
        ),
      ],
    );
  }
}

/// One account: avatar (the profile photo for the open one), name and
/// phone, a check on the open one and Log out on the others.
class _AccountRow extends ConsumerWidget implements SettingsGroupRow {
  const _AccountRow({
    required this.account,
    required this.number,
    required this.isActive,
    required this.enabled,
    required this.onSwitch,
    required this.onLogOut,
  });

  final AccountEntry account;
  final int number;
  final bool isActive;
  final bool enabled;
  final VoidCallback onSwitch;
  final void Function(String title) onLogOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final title = accountTitle(account, l10n, number);
    final photo = isActive ? ref.watch(accountProfileProvider).value : null;
    final String? subtitle;
    if (account.isSignedIn) {
      subtitle = formatPhone(account.phoneNumber);
    } else if (account.recovered) {
      subtitle = null;
    } else {
      subtitle = l10n.notSignedIn;
    }
    return SettingsRow(
      key: ValueKey('account-${account.slot}'),
      leading: SenderAvatar(name: title, size: 28, photo: photo?.photo),
      title: title,
      subtitle: subtitle,
      trailing: AnimatedSwitcher(
        duration: settingsMotionOf(context),
        child: isActive
            ? MgIcon(
                MgIcons.check,
                key: const ValueKey('active'),
                size: 16,
                color: c.accent,
              )
            : SettingsButton(
                key: ValueKey('logOut-${account.slot}'),
                label: l10n.logOut,
                onPressed: enabled ? () => onLogOut(title) : null,
              ),
      ),
      onTap: isActive || !enabled ? null : onSwitch,
    );
  }
}

/// A group row with a text field: the [label] on the left and the value
/// on the right, or a full-width field when there is only a [placeholder].
/// The change is sent on Enter or when the field loses focus; Esc puts the
/// saved value back. While a save is running a spinner replaces
/// [trailing]; a refused save keeps the typed text for another try.
class _FieldRow extends StatefulWidget {
  const _FieldRow({
    super.key,
    required this.value,
    required this.onCommit,
    this.label,
    this.placeholder,
    this.prefix,
    this.maxLength,
    this.trailing,
    this.onChanged,
    this.onFocusChanged,
  });

  final String value;
  final String? label;
  final String? placeholder;

  /// Drawn before the text, such as the @ of a username.
  final String? prefix;
  final int? maxLength;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onFocusChanged;

  /// Saves the text; completes with whether it was accepted.
  final Future<bool> Function(String value) onCommit;

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  late final _text = TextEditingController(text: widget.value);
  late final _focus = FocusNode(onKeyEvent: _onKey);
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(_FieldRow old) {
    super.didUpdateWidget(old);
    // A fresh profile replaces the text unless the user is typing.
    if (old.value != widget.value && !_focus.hasFocus) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    // Leaving the page with an edit in the field still saves it, as
    // moving the focus away would.
    if (!_saving && _text.text.trim() != widget.value.trim()) {
      unawaited(widget.onCommit(_text.text));
    }
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    _text.text = widget.value;
    widget.onChanged?.call(widget.value);
    node.unfocus();
    return KeyEventResult.handled;
  }

  void _focusChanged() {
    widget.onFocusChanged?.call(_focus.hasFocus);
    if (!_focus.hasFocus) unawaited(_commit());
  }

  Future<void> _commit() async {
    if (!mounted || _saving || _text.text.trim() == widget.value.trim()) {
      return;
    }
    setState(() => _saving = true);
    final accepted = await widget.onCommit(_text.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (accepted) _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final style = mgTextStyle(c, height: 1.3);
    final label = widget.label;
    final field = TextField(
      controller: _text,
      focusNode: _focus,
      maxLength: widget.maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textAlign: label == null ? TextAlign.start : TextAlign.end,
      style: style,
      cursorHeight: 15,
      onChanged: widget.onChanged,
      onSubmitted: (_) => unawaited(_commit()),
      decoration: InputDecoration.collapsed(
        // A labelled field has no hint: it would widen the hugging value.
        hintText: widget.placeholder,
        hintStyle: style.copyWith(color: c.fg2),
      ).copyWith(counterText: ''),
    );
    final prefix = widget.prefix;
    const spinner = SettingsSpinner(size: 12);
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focus.requestFocus,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: settingsInset,
              vertical: 10,
            ),
            child: Row(
              children: [
                if (label != null) ...[
                  Text(label, style: style),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: label == null
                      ? field
                      // The value hugs the right edge, the prefix hugs the
                      // value.
                      : LayoutBuilder(
                          builder: (context, constraints) => Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_saving) ...[
                                spinner,
                                const SizedBox(width: 8),
                              ],
                              if (prefix != null)
                                Text(
                                  prefix,
                                  style: style.copyWith(color: c.fg2),
                                ),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: 24,
                                  maxWidth: constraints.maxWidth - 40,
                                ),
                                child: IntrinsicWidth(child: field),
                              ),
                            ],
                          ),
                        ),
                ),
                // A labelled value keeps its place while saving: the
                // spinner goes before it. A full-width field reserves room.
                if (label == null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 22,
                    child: _saving ? spinner : widget.trailing,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
