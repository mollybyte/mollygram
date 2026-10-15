import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../chat/message_tile.dart' show SenderAvatar;

/// Asks whose messages to search: a popover under [position] with a
/// search field and the group's members by name, as the "From" filter in
/// Telegram for macOS. Null when dismissed.
Future<MentionCandidate?> pickSearchSender(
  BuildContext context, {
  required Offset position,
  required Future<List<MentionCandidate>> Function(String query) search,
}) async {
  MentionCandidate? picked;
  await showMgPopover(
    context,
    position: position,
    child: _SenderPicker(
      search: search,
      onPick: (candidate) {
        picked = candidate;
        Navigator.of(context).pop();
      },
    ),
  );
  return picked;
}

class _SenderPicker extends StatefulWidget {
  const _SenderPicker({required this.search, required this.onPick});

  final Future<List<MentionCandidate>> Function(String query) search;
  final ValueChanged<MentionCandidate> onPick;

  @override
  State<_SenderPicker> createState() => _SenderPickerState();
}

class _SenderPickerState extends State<_SenderPicker> {
  final _query = TextEditingController();
  final _focus = FocusNode(debugLabel: 'search sender');
  Timer? _debounce;
  var _generation = 0;
  List<MentionCandidate>? _found;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
    unawaited(_run());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 200),
      () => unawaited(_run()),
    );
  }

  Future<void> _run() async {
    final generation = ++_generation;
    List<MentionCandidate> found;
    try {
      found = await widget.search(_query.text.trim());
    } on Object {
      found = const [];
    }
    if (!mounted || generation != _generation) return;
    setState(() => _found = found);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final found = _found;
    return Glass(
      radius: 12,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MgSearchField(
              controller: _query,
              focusNode: _focus,
              hintText: l10n.searchHint,
              onChanged: _changed,
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: switch (found) {
                null => const SizedBox(height: 40),
                [] => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    l10n.nothingFound,
                    textAlign: TextAlign.center,
                    style: mgTextStyle(c, color: c.fg2),
                  ),
                ),
                _ => ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: found.length,
                  itemBuilder: (context, index) => _SenderRow(
                    candidate: found[index],
                    onTap: () => widget.onPick(found[index]),
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SenderRow extends StatefulWidget {
  const _SenderRow({required this.candidate, required this.onTap});

  final MentionCandidate candidate;
  final VoidCallback onTap;

  @override
  State<_SenderRow> createState() => _SenderRowState();
}

class _SenderRowState extends State<_SenderRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final candidate = widget.candidate;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: _hover ? c.hover : const Color(0x00000000),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SenderAvatar(
                name: candidate.name,
                size: 26,
                photo: candidate.photo,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  candidate.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(c, height: 1.3),
                ),
              ),
              if (candidate.username.isNotEmpty)
                Text(
                  '@${candidate.username}',
                  style: mgTextStyle(c, size: MgType.small, color: c.fg2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
