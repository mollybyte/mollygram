import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../avatar/peer_avatar.dart';
import '../home/workspace.dart';
import '../session/providers.dart';
import 'add_contact_form.dart';
import 'presence.dart';
import 'providers.dart';

/// What the people sheet opens on.
enum PeopleSheetMode {
  /// Pick someone to write to: recent chats and contacts, and usernames
  /// from the global search.
  newMessage,

  /// The contacts, with adding and deleting.
  contacts,

  /// Pick a person to start a secret chat with.
  newSecretChat,
}

/// Opens the sheet over the window. Choosing a person or chat opens it in
/// the workspace, revealing it when it is already open.
Future<void> showPeopleSheet(
  BuildContext context, {
  PeopleSheetMode mode = PeopleSheetMode.newMessage,
}) => showMgSheet<void>(context, PeopleSheet(mode: mode));

/// A row of the sheet: a section title, a person or a public chat.
sealed class _Row {
  const _Row();
}

final class _Section extends _Row {
  const _Section(this.title);

  final String title;
}

final class _Person extends _Row {
  const _Person(this.user);

  final ContactUser user;
}

final class _PublicChat extends _Row {
  const _PublicChat(this.chat);

  final ChatListEntry chat;
}

class PeopleSheet extends ConsumerStatefulWidget {
  const PeopleSheet({super.key, this.mode = PeopleSheetMode.newMessage});

  final PeopleSheetMode mode;

  /// How many recent private chats the new message sheet lists.
  static const recentCount = 5;

  @override
  ConsumerState<PeopleSheet> createState() => _PeopleSheetState();
}

class _PeopleSheetState extends ConsumerState<PeopleSheet> {
  late var _mode = widget.mode;
  var _adding = false;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _selectedKey = GlobalKey();
  var _selected = 0;
  Timer? _debounce;
  var _searchId = 0;

  /// What TDLib found for the query; null while there is none.
  List<ContactUser>? _found;
  List<int> _public = const [];
  String? _error;

  ContactsController get _contacts => ref.read(contactsControllerProvider);

  @override
  void initState() {
    super.initState();
    _searchFocus.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    // Results for the previous query are dropped, and a request still
    // running for it is ignored when it returns.
    _searchId++;
    setState(() {
      _selected = 0;
      _error = null;
      _found = null;
      _public = const [];
    });
    if (value.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 200), () => _find(value));
  }

  Future<void> _find(String query) async {
    final id = ++_searchId;
    final contacts = _contacts;
    final global = _mode != PeopleSheetMode.contacts;
    final chats = _mode == PeopleSheetMode.newMessage;
    final (found, public) = await (
      contacts
          .search(query, includeChats: global)
          .catchError((Object _) => <ContactUser>[]),
      chats ? contacts.searchPublic(query) : Future.value(const <int>[]),
    ).wait;
    if (!mounted || id != _searchId) return;
    setState(() {
      _found = found;
      _public = public;
    });
  }

  List<_Row> _rows(AppLocalizations l10n, List<ContactUser>? contacts) {
    final query = _search.text.trim().toLowerCase();
    final session = ref.read(telegramSessionProvider).requireValue;
    final chatLists = session.chatLists;
    final rows = <_Row>[];
    // A secret chat needs another person: bots and the user themselves
    // cannot take part, so they are left out (counted as already shown).
    final shown = <int>{
      if (_mode == PeopleSheetMode.newSecretChat) ...[
        ?session.peers.myId,
        for (final user in [...?contacts, ...?_found])
          if (user.isBot) user.id,
      ],
    };
    if (query.isEmpty) {
      if (_mode != PeopleSheetMode.contacts) {
        // In TDLib a private chat has the id of its user.
        final recent =
            [
                  for (final chat in chatLists.store.chatsFor(
                    const ChatListLocation.main(),
                  ))
                    ?_contacts.user(chat.id),
                ]
                .where((user) => !user.isBot && !shown.contains(user.id))
                .take(PeopleSheet.recentCount);
        if (recent.isNotEmpty) {
          rows.add(_Section(l10n.recentChats));
          for (final user in recent) {
            rows.add(_Person(user));
            shown.add(user.id);
          }
        }
      }
      // Contacts already listed under Recent are not repeated.
      final rest = [
        for (final user in contacts ?? const <ContactUser>[])
          if (shown.add(user.id)) user,
      ];
      if (_mode != PeopleSheetMode.contacts && rest.isNotEmpty) {
        rows.add(_Section(l10n.contacts));
      }
      rows.addAll(rest.map(_Person.new));
      return rows;
    }
    // Loaded contacts match at once; TDLib's search adds the rest.
    for (final user in contacts ?? const <ContactUser>[]) {
      if (_matches(user, query) && shown.add(user.id)) rows.add(_Person(user));
    }
    for (final user in _found ?? const <ContactUser>[]) {
      if (shown.add(user.id)) rows.add(_Person(user));
    }
    final public = [
      for (final id in _public)
        if (!shown.contains(id)) ?chatLists.store.chat(id),
    ];
    if (public.isNotEmpty) {
      rows.add(_Section(l10n.globalSearch));
      rows.addAll(public.map(_PublicChat.new));
    }
    return rows;
  }

  static bool _matches(ContactUser user, String query) =>
      user.name.toLowerCase().contains(query) ||
      user.username.toLowerCase().contains(query);

  Future<void> _open(_Row row) async {
    final workspace = ref.read(workspaceControllerProvider);
    final navigator = Navigator.of(context);
    final int chatId;
    switch (row) {
      case _Person(:final user) when _mode == PeopleSheetMode.newSecretChat:
        final secretChats = ref
            .read(telegramSessionProvider)
            .requireValue
            .secretChats;
        try {
          chatId = await secretChats.create(user.id);
        } on Object {
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            setState(() => _error = l10n.secretChatFailed);
          }
          return;
        }
      case _Person(:final user):
        try {
          chatId = await _contacts.privateChat(user.id);
        } on Object {
          return;
        }
      case _PublicChat(:final chat):
        chatId = chat.id;
      case _Section():
        return;
    }
    if (!mounted) return;
    workspace.open(chatId);
    navigator.pop();
  }

  Future<void> _delete(ContactUser user) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.deleteContactTitle(user.name),
      confirmLabel: l10n.menuDelete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null || !mounted) return;
    try {
      await _contacts.remove(user.id);
    } on Object {
      if (mounted) setState(() => _error = l10n.deleteContactFailed);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, List<_Row> selectable) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowUp:
        if (selectable.isEmpty) return KeyEventResult.handled;
        final delta = event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
        setState(
          () => _selected = (_selected + delta).clamp(0, selectable.length - 1),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final row = _selectedKey.currentContext;
          if (row != null && row.mounted) {
            Scrollable.ensureVisible(
              row,
              alignmentPolicy: delta > 0
                  ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
                  : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
            );
          }
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (event is KeyDownEvent && selectable.isNotEmpty) {
          unawaited(
            _open(selectable[_selected.clamp(0, selectable.length - 1)]),
          );
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (event is KeyDownEvent) Navigator.of(context).pop();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _closeForm() {
    setState(() => _adding = false);
    _searchFocus.requestFocus();
  }

  void _setMode(PeopleSheetMode mode) => setState(() {
    _mode = mode;
    _adding = false;
    _selected = 0;
    _search.clear();
    _found = null;
    _public = const [];
    _error = null;
    _searchFocus.requestFocus();
  });

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final contacts = ref.watch(contactsProvider).value;
    // Recent chats change as messages arrive.
    ref.watch(chatListProvider(const ChatListLocation.main()));
    final rows = _rows(l10n, contacts);
    final selectable = [
      for (final row in rows)
        if (row is! _Section) row,
    ];
    final selected = selectable.isEmpty
        ? null
        : selectable[_selected.clamp(0, selectable.length - 1)];
    final title = _adding
        ? l10n.addContact
        : switch (_mode) {
            PeopleSheetMode.newMessage => l10n.newMessage,
            PeopleSheetMode.contacts => l10n.contacts,
            PeopleSheetMode.newSecretChat => l10n.newSecretChat,
          };

    final Widget body;
    if (_adding) {
      body = AddContactForm(
        key: const ValueKey('add'),
        onDone: (userId) => _closeForm(),
        onCancel: () => _closeForm(),
      );
    } else {
      body = Column(
        key: ValueKey(_mode),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            onKeyEvent: (node, event) => _onKey(node, event, selectable),
            child: MgSearchField(
              focusNode: _searchFocus,
              controller: _search,
              hintText: l10n.peopleSearchHint,
              onChanged: _onQuery,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: contacts == null && rows.isEmpty
                ? const SizedBox.shrink()
                : rows.isEmpty
                ? Center(
                    child: Text(
                      _search.text.trim().isEmpty
                          ? l10n.noContacts
                          : l10n.nothingFound,
                      style: mgTextStyle(c, color: c.fg2),
                    ),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) => switch (rows[i]) {
                      _Section(:final title) => _SectionTitle(title),
                      final row => _PersonRow(
                        key: row == selected ? _selectedKey : null,
                        row: row,
                        selected: row == selected,
                        onHover: () =>
                            setState(() => _selected = selectable.indexOf(row)),
                        onTap: () => unawaited(_open(row)),
                        onDelete:
                            _mode == PeopleSheetMode.contacts &&
                                row is _Person &&
                                row.user.isContact
                            ? () => unawaited(_delete(row.user))
                            : null,
                      ),
                    },
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                _error!,
                style: mgTextStyle(c, size: MgType.small, color: c.fg2),
              ),
            ),
        ],
      );
    }

    return SizedBox(
      width: 360,
      height: 480,
      child: Glass(
        radius: MgRadius.popover,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  if (_adding || widget.mode != _mode)
                    MgIconButton(
                      icon: MgIcons.back,
                      tooltip: l10n.back,
                      iconSize: 16,
                      onPressed: () =>
                          _adding ? _closeForm() : _setMode(widget.mode),
                    )
                  else
                    const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(c, weight: FontWeight.w600),
                    ),
                  ),
                  if (!_adding && _mode == PeopleSheetMode.newMessage)
                    MgTextButton(
                      key: const ValueKey('newSecretChat'),
                      label: l10n.secretChat,
                      onPressed: () => _setMode(PeopleSheetMode.newSecretChat),
                    ),
                  if (!_adding && _mode == PeopleSheetMode.newMessage)
                    MgTextButton(
                      label: l10n.contacts,
                      onPressed: () => _setMode(PeopleSheetMode.contacts),
                    ),
                  if (!_adding && _mode == PeopleSheetMode.contacts)
                    MgTextButton(
                      label: l10n.addContact,
                      onPressed: () => setState(() => _adding = true),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: MgMotion.standard,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Text(
        title,
        style: mgTextStyle(
          c,
          size: MgType.small,
          weight: FontWeight.w500,
          color: c.fg2,
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    super.key,
    required this.row,
    required this.selected,
    required this.onHover,
    required this.onTap,
    this.onDelete,
  });

  final _Row row;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  /// Shown on the selected row of a contact.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final (name, subtitle, online) = switch (row) {
      _Person(:final user) => (
        user.name,
        formatPresence(l10n, user, locale: locale),
        user.presence.kind == PresenceKind.online && !user.isBot,
      ),
      _PublicChat(:final chat) => (chat.title, '', false),
      _Section() => ('', '', false),
    };
    final fg = selected ? c.onAccent : c.fg;
    final fg2 = selected
        ? c.onAccentSecondary
        : online
        ? c.accent
        : c.fg2;
    final delete = onDelete;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onHover: (_) {
        if (!selected) onHover();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: selected,
          label: subtitle.isEmpty ? name : '$name, $subtitle',
          excludeSemantics: true,
          child: AnimatedContainer(
            duration: MgMotion.fast,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? c.accent : c.accent.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                switch (row) {
                  _Person(:final user) => PeerAvatar(
                    name: name,
                    size: 32,
                    photo: user.photo,
                  ),
                  _PublicChat(:final chat) => PeerAvatar.chat(
                    name: name,
                    size: 32,
                    photo: chat.photo,
                  ),
                  _Section() => MonogramAvatar(name: name, size: 32),
                },
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(
                          c,
                          size: MgType.title,
                          weight: FontWeight.w500,
                          color: fg,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(
                            c,
                            size: MgType.caption,
                            color: fg2,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
                if (delete != null && selected)
                  _DeleteButton(tooltip: l10n.deleteContact, onTap: delete),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small round button on the selected (accent) row.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.onAccent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: MgIcon(MgIcons.close, size: 13, color: c.onAccent),
          ),
        ),
      ),
    );
  }
}
