import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../contacts/presence.dart';
import '../contacts/providers.dart';
import '../profile/manage_sheet.dart';
import 'message_tile.dart' show SenderAvatar;

/// Asks which contact to send: a sheet with a search field and the
/// contacts by name, as Telegram for macOS offers them under the attach
/// button. Null when the sheet is dismissed.
Future<ContactUser?> pickContact(BuildContext context) =>
    showManageSheet<ContactUser>(context, const _ContactPicker());

class _ContactPicker extends ConsumerStatefulWidget {
  const _ContactPicker();

  @override
  ConsumerState<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends ConsumerState<_ContactPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final query = _search.text.trim().toLowerCase();
    final loaded = ref.watch(contactsProvider).value;
    final contacts = [
      for (final user in loaded ?? const <ContactUser>[])
        if (!user.isBot && user.name.toLowerCase().contains(query)) user,
    ];
    final now = DateTime.now();
    return ManageSheetFrame(
      title: l10n.sendContactTitle,
      height: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MgSearchField(
            controller: _search,
            hintText: l10n.searchHint,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    // Nothing yet while the contacts load.
                    child: loaded == null
                        ? const SizedBox()
                        : Text(
                            l10n.nothingFound,
                            style: mgTextStyle(c, color: c.fg2),
                          ),
                  )
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, i) {
                      final user = contacts[i];
                      return _ContactRow(
                        user: user,
                        status: formatPresence(
                          l10n,
                          user,
                          locale: l10n.localeName,
                          now: now,
                        ),
                        onTap: () => Navigator.of(context).pop(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// One contact: avatar, name and when they were last seen. Brightens
/// under the pointer; a tap picks it.
class _ContactRow extends StatefulWidget {
  const _ContactRow({
    required this.user,
    required this.status,
    required this.onTap,
  });

  final ContactUser user;
  final String status;
  final VoidCallback onTap;

  @override
  State<_ContactRow> createState() => _ContactRowState();
}

class _ContactRowState extends State<_ContactRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final user = widget.user;
    return Semantics(
      button: true,
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
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: _hover ? c.hover : const Color(0x00000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SenderAvatar(name: user.name, size: 30, photo: user.photo),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(c, height: 1.3),
                      ),
                      Text(
                        widget.status,
                        maxLines: 1,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
