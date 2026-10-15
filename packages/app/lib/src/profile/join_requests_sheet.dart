import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../../l10n/app_localizations.dart';
import '../chat/message_tile.dart' show SenderAvatar;
import '../session/providers.dart';
import 'manage_sheet.dart';

/// The people waiting to join by a link that needs approval, each with
/// Approve and Dismiss.
class JoinRequestsSheet extends ConsumerStatefulWidget {
  const JoinRequestsSheet({super.key, required this.chatId});

  final int chatId;

  @override
  ConsumerState<JoinRequestsSheet> createState() => _JoinRequestsSheetState();
}

class _JoinRequestsSheetState extends ConsumerState<JoinRequestsSheet> {
  late final ChatManagement _management = ref
      .read(telegramSessionProvider)
      .requireValue
      .management;
  List<JoinRequest>? _requests;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final requests = await _management.joinRequests(widget.chatId);
      if (mounted) {
        setState(() {
          _requests = requests;
          _failed = false;
        });
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _process(JoinRequest request, {required bool approve}) async {
    try {
      await _management.processJoinRequest(
        widget.chatId,
        request.userId,
        approve: approve,
      );
      if (mounted) {
        setState(() => _requests = [...?_requests?.where((r) => r != request)]);
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final requests = _requests;
    return ManageSheetFrame(
      title: l10n.joinRequests,
      height: 420,
      error: _failed ? l10n.membersFailed : null,
      child: requests == null
          ? const SizedBox.shrink()
          : requests.isEmpty
          ? SheetNotice(l10n.noJoinRequests)
          : ListView(
              children: [
                for (final request in requests)
                  PersonRow(
                    name: request.name,
                    avatar: SenderAvatar(
                      name: request.name,
                      size: 30,
                      photo: request.photo,
                    ),
                    subtitle: [
                      l10n.requestedOn(
                        DateFormat.MMMd(l10n.localeName).format(request.date),
                      ),
                      if (request.bio.isNotEmpty) request.bio,
                    ].join(' · '),
                    actions: [
                      (
                        l10n.approve,
                        () => unawaited(_process(request, approve: true)),
                      ),
                      (
                        l10n.dismiss,
                        () => unawaited(_process(request, approve: false)),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
