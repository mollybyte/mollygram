import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../contacts/presence.dart';
import '../contacts/providers.dart';
import '../session/providers.dart';
import 'manage_sheet.dart';
import 'new_chat_sheet.dart' show PickRow;

/// Picks contacts to add to a group or channel that exists.
class AddMembersSheet extends ConsumerStatefulWidget {
  const AddMembersSheet({
    super.key,
    required this.chatId,
    required this.channel,
  });

  final int chatId;
  final bool channel;

  @override
  ConsumerState<AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends ConsumerState<AddMembersSheet> {
  final _search = TextEditingController();
  final _picked = <int, String>{};
  var _busy = false;
  var _failed = false;
  List<String>? _notAdded;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final notAdded = await ref
          .read(telegramSessionProvider)
          .requireValue
          .management
          .addMembers(widget.chatId, [..._picked.keys]);
      if (!mounted) return;
      if (notAdded.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _busy = false;
        _notAdded = [for (final id in notAdded) _picked[id] ?? '$id'];
      });
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
    final title = widget.channel ? l10n.addSubscribers : l10n.addMembers;
    if (_notAdded case final names?) {
      return ManageSheetFrame(
        title: title,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            l10n.notAddedMembers(names.length, names.join(', ')),
            style: mgTextStyle(c, color: c.fg2),
          ),
        ),
      );
    }
    final query = _search.text.trim().toLowerCase();
    final contacts = [
      for (final user
          in ref.watch(contactsProvider).value ?? const <ContactUser>[])
        if (!user.isBot && user.name.toLowerCase().contains(query)) user,
    ];
    final now = DateTime.now();
    return ManageSheetFrame(
      title: title,
      height: 460,
      action: l10n.add,
      busy: _busy,
      error: _failed ? l10n.memberChangeFailed : null,
      onAction: _busy || _picked.isEmpty ? null : _add,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MgSearchField(
            controller: _search,
            hintText: l10n.addMembersHint,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: contacts.isEmpty
                ? SheetNotice(l10n.nothingFound)
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, i) {
                      final user = contacts[i];
                      return PickRow(
                        name: user.name,
                        photo: user.photo,
                        status: formatPresence(
                          l10n,
                          user,
                          locale: l10n.localeName,
                          now: now,
                        ),
                        picked: _picked.containsKey(user.id),
                        onTap: () => setState(
                          () => _picked.remove(user.id) == null
                              ? _picked[user.id] = user.name
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
