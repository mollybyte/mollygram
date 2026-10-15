import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import 'manage_sheet.dart';

/// Whether a group or channel is public, at t.me/username, or private,
/// reached by invite links only; with the username checked as typed.
class ChatTypeSheet extends ConsumerStatefulWidget {
  const ChatTypeSheet({super.key, required this.settings});

  final ChatSettings settings;

  @override
  ConsumerState<ChatTypeSheet> createState() => _ChatTypeSheetState();
}

class _ChatTypeSheetState extends ConsumerState<ChatTypeSheet> {
  late final ChatManagement _management = ref
      .read(telegramSessionProvider)
      .requireValue
      .management;
  late var _public = widget.settings.isPublic;
  late final _username = TextEditingController(text: widget.settings.username);
  UsernameCheck? _check;
  Timer? _debounce;
  var _busy = false;
  var _failed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() => _check = null);
    final username = value.trim();
    if (username.isEmpty || username == widget.settings.username) return;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final check = await _management.checkUsername(
          widget.settings.chatId,
          username,
        );
        if (mounted && _username.text.trim() == username) {
          setState(() => _check = check);
        }
      } on Object {
        if (mounted) setState(() => _check = UsernameCheck.invalid);
      }
    });
  }

  Future<void> _save() async {
    final username = _public ? _username.text.trim() : '';
    if (username == widget.settings.username) {
      Navigator.of(context).pop();
      return;
    }
    if (_public && (username.isEmpty || _check == UsernameCheck.invalid)) {
      setState(() => _check ??= UsernameCheck.invalid);
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await _management.setUsername(widget.settings.chatId, username);
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
    final channel = widget.settings.isChannel;
    final check = _check;
    final (String checkText, Color checkColor) = switch (check) {
      null => ('', c.fg2),
      UsernameCheck.ok => (l10n.chatLinkAvailable, c.accent),
      UsernameCheck.occupied => (l10n.usernameTaken, MgDestructive.color),
      UsernameCheck.purchasable => (l10n.usernameTaken, MgDestructive.color),
      UsernameCheck.tooMany => (l10n.usernameTooMany, MgDestructive.color),
      UsernameCheck.invalid => (l10n.usernameInvalid, MgDestructive.color),
    };
    return ManageSheetFrame(
      title: channel ? l10n.channelType : l10n.groupType,
      action: l10n.save,
      busy: _busy,
      error: _failed ? l10n.saveFailed : null,
      onAction: _busy ? null : _save,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChoiceRow<bool>(
              value: _public,
              onChanged: (value) => setState(() => _public = value),
              options: [(false, l10n.privateChat), (true, l10n.publicChat)],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                _public
                    ? (channel ? l10n.publicChannelNote : l10n.publicGroupNote)
                    : (channel
                          ? l10n.privateChannelNote
                          : l10n.privateGroupNote),
                style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_public
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Text(
                                't.me/',
                                style: mgTextStyle(c, size: 14, color: c.fg2),
                              ),
                            ),
                            Expanded(
                              child: MgUnderlineField(
                                controller: _username,
                                hintText: l10n.chatLinkHint,
                                autofocus: true,
                                fontSize: 14,
                                onChanged: _onChanged,
                                onSubmitted: (_) {
                                  if (!_busy) unawaited(_save());
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 140),
                          opacity: checkText.isEmpty ? 0 : 1,
                          child: Text(
                            checkText.isEmpty ? ' ' : checkText,
                            style: mgTextStyle(
                              c,
                              size: MgType.caption,
                              color: checkColor,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
